extends Control

signal textbox_closed
signal forced_switch_done

@export var ally_team: Array[Resource] = []
@export var enemy_team: Array[Resource] = []

var ally_active_idx := 0
var enemy_active_idx := 0
var ally_active: Resource
var enemy_active: Resource

var ally_hp: Array[int] = []
var enemy_hp: Array[int] = []
var ally_max_hp: Array[int] = []
var enemy_max_hp: Array[int] = []

const DEBUG := false

@onready var textbox: Control = $Textbox
@onready var textbox_label: Label = $Textbox/Label
@onready var action_panel: Control = $ActionPanel
@onready var move_panel: Control = $MovePanel
@onready var switch_panel: Control = $SwitchPanel
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var ally_bar: ProgressBar = $AllyHud/AllyHealth
@onready var enemy_bar: ProgressBar = $EnemyHud/EnemyHealth
@onready var ally_sprite: TextureRect = $AllyContainer/Ally
@onready var enemy_sprite: TextureRect = $EnemyContainer/Enemy
@onready var move_buttons: Array = $"MovePanel/Actions".get_children()
@onready var switch_buttons: Array = $"SwitchPanel/Actions".get_children()
@onready var ally_name: Label = $AllyHud/Name
@onready var ally_level: Label = $AllyHud/Level
@onready var enemy_name: Label = $EnemyHud/Name
@onready var enemy_level: Label = $EnemyHud/Level

# Prevent accidental double-press / re-entry
var turn_busy := false

# True only when a mon fainted and player MUST choose replacement.
# In this mode, switching does NOT trigger enemy_turn().
var forcing_switch := false


# ----------------------------
# Turn lock helpers
# ----------------------------

func _try_lock_turn() -> bool:
	if turn_busy:
		return false
	turn_busy = true
	return true

func _unlock_turn() -> void:
	turn_busy = false


# ----------------------------
# UI visibility helpers (NO OVERLAP)
# Exactly ONE of: textbox/action/move/switch is visible at a time.
# ----------------------------

func hide_all_panels() -> void:
	textbox.hide()
	action_panel.hide()
	move_panel.hide()
	switch_panel.hide()

func show_action_panel() -> void:
	hide_all_panels()
	action_panel.show()

func show_move_panel() -> void:
	hide_all_panels()
	move_panel.show()

func show_switch_panel() -> void:
	hide_all_panels()
	switch_panel.show()

func show_textbox(text: String) -> void:
	hide_all_panels()
	textbox.show()
	textbox_label.text = text


# ----------------------------
# Stat helpers
# ----------------------------

func calcHP(base, iv, ev, level):
	var evTerm = floor(ev / 4)
	return floor(((2 * base + iv + evTerm) * level) / 100) + level + 10

func calcStat(base, iv, ev, level):
	var evTerm = floor(ev / 4)
	var raw = floor(((2 * base + iv + evTerm) * level) / 100) + 5
	return raw

func get_speed(mon: Resource) -> int:
	return calcStat(mon.base_speed, mon.IV_speed, mon.EV_speed, mon.level)


# ----------------------------
# Init
# ----------------------------

func _ready() -> void:
	randomize()
	hide_all_panels()

	if ally_team.is_empty() or enemy_team.is_empty():
		push_error("Ally team and Enemy team must each have at least 1 monster.")
		return

	for i in range(ally_team.size()):
		if ally_team[i] != null:
			ally_team[i] = ally_team[i].duplicate(true)
	for i in range(enemy_team.size()):
		if enemy_team[i] != null:
			enemy_team[i] = enemy_team[i].duplicate(true)

	ally_hp.clear()
	ally_max_hp.clear()
	for mon in ally_team:
		if mon == null:
			ally_hp.append(0)
			ally_max_hp.append(1)
			continue
		var max_hp = calcHP(mon.base_health, mon.IV_health, mon.EV_health, mon.level)
		ally_max_hp.append(max_hp)
		ally_hp.append(max_hp)

	enemy_hp.clear()
	enemy_max_hp.clear()
	for mon in enemy_team:
		if mon == null:
			enemy_hp.append(0)
			enemy_max_hp.append(1)
			continue
		var max_hp = calcHP(mon.base_health, mon.IV_health, mon.EV_health, mon.level)
		enemy_max_hp.append(max_hp)
		enemy_hp.append(max_hp)

	ally_active_idx = find_next_alive_ally(-1)
	enemy_active_idx = find_next_alive_enemy(-1)

	if ally_active_idx == -1 or enemy_active_idx == -1:
		push_error("Could not find a usable active monster (null or all fainted).")
		return

	ally_active = ally_team[ally_active_idx]
	enemy_active = enemy_team[enemy_active_idx]

	setup_active_ui()

	# Safe connect: avoids double-connection if also connected in editor.
	for i in range(switch_buttons.size()):
		var btn: Button = switch_buttons[i]
		var cb := Callable(self, "_on_switch_button_pressed").bind(i)
		if not btn.pressed.is_connected(cb):
			btn.pressed.connect(cb)

	display_text("a wild %s appears" % enemy_active.name)
	await textbox_closed
	show_action_panel()


# ----------------------------
# Helpers
# ----------------------------

func can_switch_now() -> bool:
	for i in range(ally_team.size()):
		if ally_team[i] != null and ally_hp[i] > 0 and i != ally_active_idx:
			return true
	return false


# ----------------------------
# Find next alive (wrap-around)
# ----------------------------

func find_next_alive_ally(from_idx: int) -> int:
	for offset in range(1, ally_team.size() + 1):
		var i := (from_idx + offset) % ally_team.size()
		if ally_team[i] != null and ally_hp[i] > 0:
			return i
	return -1

func find_next_alive_enemy(from_idx: int) -> int:
	for offset in range(1, enemy_team.size() + 1):
		var i := (from_idx + offset) % enemy_team.size()
		if enemy_team[i] != null and enemy_hp[i] > 0:
			return i
	return -1


# ----------------------------
# UI
# ----------------------------

func set_health(bar: ProgressBar, hp: int, max_hp: int) -> void:
	bar.max_value = max_hp
	bar.value = clamp(hp, 0, max_hp)

func setup_active_ui() -> void:
	ally_name.text = ally_active.name
	enemy_name.text = enemy_active.name

	ally_level.text = ("lvl: %s" % ally_active.level)
	enemy_level.text = ("lvl: %s" % enemy_active.level)

	ally_sprite.texture = ally_active.back_texture
	enemy_sprite.texture = enemy_active.texture

	set_health(ally_bar, ally_hp[ally_active_idx], ally_max_hp[ally_active_idx])
	set_health(enemy_bar, enemy_hp[enemy_active_idx], enemy_max_hp[enemy_active_idx])

	set_move_buttons_for_active()

func set_move_buttons_for_active() -> void:
	for i in range(move_buttons.size()):
		var btn: Button = move_buttons[i]
		if i < ally_active.moves.size() and ally_active.moves[i] != null:
			btn.text = ally_active.moves[i].name
			btn.disabled = false
		else:
			btn.text = "-"
			btn.disabled = true

func refresh_switch_buttons() -> void:
	for i in range(switch_buttons.size()):
		var btn: Button = switch_buttons[i]

		if i >= ally_team.size():
			btn.text = "-"
			btn.disabled = true
			continue

		var mon = ally_team[i]
		if mon == null:
			btn.text = "-"
			btn.disabled = true
			continue

		btn.text = "%s (%d/%d)" % [mon.name, ally_hp[i], ally_max_hp[i]]
		btn.disabled = (ally_hp[i] <= 0) or (i == ally_active_idx)


# ----------------------------
# Textbox (NO OVERLAP)
# ----------------------------

func display_text(text: String) -> void:
	if DEBUG: print("DISPLAY:", text)
	show_textbox(text)

func close_textbox() -> void:
	if not textbox.visible:
		return
	textbox.hide()
	emit_signal("textbox_closed")

func _unhandled_input(event: InputEvent) -> void:
	if not textbox.visible:
		return

	if event.is_action_pressed("ui_accept"):
		close_textbox()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close_textbox()

func _on_textbox_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close_textbox()


# ----------------------------
# Animation helper
# ----------------------------

func play_anim_safe(anim_name: String) -> void:
	if not anim.has_animation(anim_name):
		push_warning("Missing animation: %s" % anim_name)
		return
	anim.play(anim_name)
	await anim.animation_finished


# ----------------------------
# Team helpers
# ----------------------------

func is_ally(mon: Resource) -> bool:
	return ally_team.has(mon)

func get_team_index(mon: Resource) -> int:
	var idx = ally_team.find(mon)
	if idx != -1:
		return idx
	return enemy_team.find(mon)

func get_current_health(mon: Resource) -> int:
	var idx = get_team_index(mon)
	if idx == -1:
		return 0
	return ally_hp[idx] if is_ally(mon) else enemy_hp[idx]

func set_current_health(mon: Resource, value: int) -> void:
	var idx = get_team_index(mon)
	if idx == -1:
		return
	if is_ally(mon):
		ally_hp[idx] = value
	else:
		enemy_hp[idx] = value

func get_max_health(mon: Resource) -> int:
	var idx = get_team_index(mon)
	if idx == -1:
		return 1
	return ally_max_hp[idx] if is_ally(mon) else enemy_max_hp[idx]

func update_health_bar(mon: Resource) -> void:
	if mon == ally_active:
		set_health(ally_bar, ally_hp[ally_active_idx], ally_max_hp[ally_active_idx])
	elif mon == enemy_active:
		set_health(enemy_bar, enemy_hp[enemy_active_idx], enemy_max_hp[enemy_active_idx])


# ----------------------------
# Switching
# ----------------------------

func _on_switch_button_pressed(i: int) -> void:
	if not _try_lock_turn():
		return

	# Validation
	if i < 0 or i >= ally_team.size():
		_unlock_turn()
		return
	if ally_team[i] == null:
		display_text("No monster in that slot!")
		await textbox_closed
		_unlock_turn()
		return
	if ally_hp[i] <= 0:
		display_text("%s has fainted!" % ally_team[i].name)
		await textbox_closed
		_unlock_turn()
		return
	if i == ally_active_idx:
		display_text("%s is already out!" % ally_team[i].name)
		await textbox_closed
		_unlock_turn()
		return

	hide_all_panels()

	ally_active_idx = i
	ally_active = ally_team[ally_active_idx]
	setup_active_ui()

	display_text("Go, %s!" % ally_active.name)
	await textbox_closed

	if forcing_switch:
		forcing_switch = false
		emit_signal("forced_switch_done")
		show_action_panel()
		_unlock_turn()
		return

	# Voluntary switch costs your turn
	await enemy_turn()

	var ended := await handle_faint_and_stop_turn()
	if ended:
		_unlock_turn()
		return

	show_action_panel()
	_unlock_turn()


# ----------------------------
# Damage / Heal (called by Move.use)
# ----------------------------

func calc_damage(power, attack, defense):
	var defense_stat = max(1, defense)
	var base = (power * attack) / defense_stat
	var K := 0.85
	var dmg = base * K
	var roll = randf_range(0.85, 1.0)
	return max(1, int(dmg * roll))

func apply_damage(attacker: Resource, target: Resource, move_power: int, move_type: int) -> void:
	var target_is_ally := is_ally(target)

	var hp := get_current_health(target)

	var atk = calcStat(attacker.base_attack, attacker.IV_attack, attacker.EV_attack, attacker.level)
	var def = calcStat(target.base_defense, target.IV_defense, target.EV_defense, target.level)

	var raw_damage = calc_damage(move_power, atk, def)

	var type_mult := TypeChart.get_multiplier(move_type, target.types)
	var stab := TypeChart.get_stab(move_type, attacker.types)

	var final_damage := int(raw_damage * stab * type_mult)

	var msg := TypeChart.get_effectiveness_text(type_mult)
	if msg != "":
		display_text(msg)
		await textbox_closed

	if type_mult == 0.0:
		final_damage = 0

	hp = max(0, hp - final_damage)
	set_current_health(target, hp)
	update_health_bar(target)

	await play_anim_safe("player_hurt" if target_is_ally else "enemy_hurt")

func apply_heal(target: Resource, amount: int) -> void:
	var target_is_ally := is_ally(target)

	var hp := get_current_health(target)
	var max_hp := get_max_health(target)
	hp = min(max_hp, hp + amount)
	set_current_health(target, hp)
	update_health_bar(target)

	var heal_anim := "player_healed" if target_is_ally else "enemy_healed"
	if anim.has_animation(heal_anim):
		await play_anim_safe(heal_anim)


# ----------------------------
# Faint handling
# ----------------------------

func check_and_handle_faint() -> bool:
	# Enemy faint -> switch or win
	if enemy_hp[enemy_active_idx] <= 0:
		display_text("%s fainted!" % enemy_active.name)
		await textbox_closed

		var next_enemy := find_next_alive_enemy(enemy_active_idx)
		if next_enemy == -1:
			display_text("you have successfully defeated the enemy team")
			await textbox_closed
			get_tree().quit()
			return true

		enemy_active_idx = next_enemy
		enemy_active = enemy_team[enemy_active_idx]
		display_text("Enemy sent out %s!" % enemy_active.name)
		await textbox_closed
		setup_active_ui()
		return false

	# Ally faint -> player chooses replacement
	if ally_hp[ally_active_idx] <= 0:
		display_text("%s fainted!" % ally_active.name)
		await textbox_closed

		if not can_switch_now():
			display_text("you have been defeated by the enemy team")
			await textbox_closed
			get_tree().quit()
			return true

		# Ensure forced-switch buttons will respond
		_unlock_turn()

		# Tell player first (textbox), then show switch panel (NO overlap).
		display_text("Choose a monster to send out!")
		await textbox_closed

		forcing_switch = true
		refresh_switch_buttons()
		show_switch_panel()

		await forced_switch_done
		return false

	return false


# ----------------------------
# Turn handling
# ----------------------------

func do_turn(move_num: int) -> void:
	hide_all_panels()

	if move_num < 0 or move_num >= ally_active.moves.size() or ally_active.moves[move_num] == null:
		display_text("That move slot is empty!")
		await textbox_closed
		show_action_panel()
		return

	var ally_speed := get_speed(ally_active)
	var enemy_speed := get_speed(enemy_active)

	var ally_first := ally_speed > enemy_speed or (ally_speed == enemy_speed and randf() < 0.5)

	if ally_first:
		await ally_active.moves[move_num].use(ally_active, enemy_active, self)

		if enemy_hp[enemy_active_idx] <= 0:
			var ended = await handle_faint_and_stop_turn()
			if ended: return
			show_action_panel()
			return

		await enemy_turn()

		if ally_hp[ally_active_idx] <= 0:
			var ended2 = await handle_faint_and_stop_turn()
			if ended2: return
			# If ally fainted, check_and_handle_faint will show switch panel.
			# After player switches, we return to action panel here:
			show_action_panel()
			return
	else:
		await enemy_turn()

		if ally_hp[ally_active_idx] <= 0:
			var ended3 = await handle_faint_and_stop_turn()
			if ended3: return
			show_action_panel()
			return

		await ally_active.moves[move_num].use(ally_active, enemy_active, self)

		if enemy_hp[enemy_active_idx] <= 0:
			var ended4 = await handle_faint_and_stop_turn()
			if ended4: return
			show_action_panel()
			return

	show_action_panel()


func handle_faint_and_stop_turn() -> bool:
	if enemy_hp[enemy_active_idx] <= 0 or ally_hp[ally_active_idx] <= 0:
		return await check_and_handle_faint()
	return false


func enemy_turn() -> void:
	if enemy_active.moves.is_empty():
		display_text("%s has no moves!" % enemy_active.name)
		await textbox_closed
		return

	var move: Move = enemy_active.moves.pick_random()
	if move == null:
		display_text("%s picked an empty move slot!" % enemy_active.name)
		await textbox_closed
		return

	await move.use(enemy_active, ally_active, self)


# ----------------------------
# Buttons
# ----------------------------

func _on_run_pressed() -> void:
	display_text("got away safely")
	await textbox_closed
	get_tree().quit()

func _on_switch_pressed():
	if forcing_switch:
		return

	if not can_switch_now():
		display_text("No other Pokémon can battle!")
		await textbox_closed
		show_action_panel()
		return

	refresh_switch_buttons()
	show_switch_panel()

func _on_attack_pressed() -> void:
	show_move_panel()

func _on_move_1_pressed() -> void: await do_turn(0)
func _on_move_2_pressed() -> void: await do_turn(1)
func _on_move_3_pressed() -> void: await do_turn(2)
func _on_move_4_pressed() -> void: await do_turn(3)
