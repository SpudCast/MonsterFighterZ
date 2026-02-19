extends Control

signal textbox_closed

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
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var ally_bar: ProgressBar = $AllyHud/AllyHealth
@onready var enemy_bar: ProgressBar = $EnemyHud/EnemyHealth
@onready var ally_sprite: TextureRect = $AllyContainer/Ally
@onready var enemy_sprite: TextureRect = $EnemyContainer/Enemy
@onready var move_buttons: Array = $"MovePanel/Actions".get_children()
@onready var ally_name: Label = $AllyHud/Name
@onready var ally_level: Label = $AllyHud/Level
@onready var enemy_name: Label = $EnemyHud/Name
@onready var enemy_level: Label = $EnemyHud/Level


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

	textbox.hide()
	action_panel.hide()
	move_panel.hide()

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

	display_text("a wild enemy appears")
	await textbox_closed
	action_panel.show()


func find_next_alive_ally(from_idx: int) -> int:
	for i in range(from_idx + 1, ally_team.size()):
		if ally_team[i] != null and ally_hp[i] > 0:
			return i
	return -1

func find_next_alive_enemy(from_idx: int) -> int:
	for i in range(from_idx + 1, enemy_team.size()):
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


# ----------------------------
# Textbox
# ----------------------------

func display_text(text: String) -> void:
	if DEBUG: print("DISPLAY:", text)
	textbox.show()
	textbox_label.text = text

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
# Faint handling (NO "free move" after switch)
# Returns true if battle ends.
# IMPORTANT CHANGE:
#   If someone faints, we switch them in and then STOP the turn so nobody
#   immediately attacks the newly-switched-in mon.
# ----------------------------

func check_and_handle_faint() -> bool:
	# Enemy faint -> switch or win (then stop)
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

		# STOP: end the turn here (prevents immediate move)
		return false

	# Ally faint -> switch or lose (then stop)
	if ally_hp[ally_active_idx] <= 0:
		display_text("%s fainted!" % ally_active.name)
		await textbox_closed

		var next_ally := find_next_alive_ally(ally_active_idx)
		if next_ally == -1:
			display_text("you have been defeated by the enemy team")
			await textbox_closed
			get_tree().quit()
			return true

		ally_active_idx = next_ally
		ally_active = ally_team[ally_active_idx]
		display_text("Go, %s!" % ally_active.name)
		await textbox_closed
		setup_active_ui()

		# STOP: end the turn here (prevents immediate move)
		return false

	return false


# ----------------------------
# Turn handling
# IMPORTANT CHANGE:
#   We end the turn if a faint happens on either action, so the next turn starts
#   with the action menu (no "free move" into the new mon).
# ----------------------------

func do_turn(move_num: int) -> void:
	action_panel.hide()
	move_panel.hide()

	if move_num < 0 or move_num >= ally_active.moves.size() or ally_active.moves[move_num] == null:
		display_text("That move slot is empty!")
		await textbox_closed
		action_panel.show()
		return

	var ally_speed := get_speed(ally_active)
	var enemy_speed := get_speed(enemy_active)

	var ally_first := ally_speed > enemy_speed or (ally_speed == enemy_speed and randf() < 0.5)

	if ally_first:
		await ally_active.moves[move_num].use(ally_active, enemy_active, self)

		# If enemy fainted and switched, stop turn here
		if enemy_hp[enemy_active_idx] <= 0:
			var ended = await handle_faint_and_stop_turn()
			if ended: return
			action_panel.show()
			return

		await enemy_turn()

		# If ally fainted and switched, stop turn here
		if ally_hp[ally_active_idx] <= 0:
			var ended2 = await handle_faint_and_stop_turn()
			if ended2: return
			action_panel.show()
			return
	else:
		await enemy_turn()

		# If ally fainted and switched, stop turn here
		if ally_hp[ally_active_idx] <= 0:
			var ended3 = await handle_faint_and_stop_turn()
			if ended3: return
			action_panel.show()
			return

		await ally_active.moves[move_num].use(ally_active, enemy_active, self)

		# If enemy fainted and switched, stop turn here
		if enemy_hp[enemy_active_idx] <= 0:
			var ended4 = await handle_faint_and_stop_turn()
			if ended4: return
			action_panel.show()
			return

	action_panel.show()


# Helper that performs the faint messaging/switching and returns true if battle ended.
# Used to "stop turn" after a KO.
func handle_faint_and_stop_turn() -> bool:
	# If either side is fainted, do the switch / win / lose flow.
	# This will switch, update UI, and then we return to action_panel without extra attacks.
	# (Battle end still quits.)
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

func _on_attack_pressed() -> void:
	action_panel.hide()
	move_panel.show()

func _on_move_1_pressed() -> void: await do_turn(0)
func _on_move_2_pressed() -> void: await do_turn(1)
func _on_move_3_pressed() -> void: await do_turn(2)
func _on_move_4_pressed() -> void: await do_turn(3)
