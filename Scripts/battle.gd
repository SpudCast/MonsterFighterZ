extends Control

signal textbox_closed

@export var enemy: Resource
@export var ally: Resource

var current_player_health := 0
var current_enemy_health := 0
var ally_speed := 0
var enemy_speed := 0

const DEBUG := false

@onready var textbox: Control = $Textbox
@onready var textbox_label: Label = $Textbox/Label
@onready var action_panel: Control = $ActionPanel
@onready var move_panel: Control = $MovePanel
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var ally_bar: ProgressBar = $AllyContainer/AllyHealth
@onready var enemy_bar: ProgressBar = $EnemyContainer/EnemyHealth
@onready var ally_sprite: TextureRect = $AllyContainer/Ally
@onready var enemy_sprite: TextureRect = $EnemyContainer/Enemy
@onready var move_buttons: Array = $"MovePanel/Actions".get_children()


func _ready() -> void:
	randomize()

	textbox.hide()
	action_panel.hide()
	move_panel.hide()

	current_player_health = ally.health
	current_enemy_health = enemy.health
	ally_speed = ally.speed
	enemy_speed = enemy.speed

	set_health(enemy_bar, current_enemy_health, enemy.health)
	set_health(ally_bar, current_player_health, ally.health)

	enemy_sprite.texture = enemy.texture
	ally_sprite.texture = ally.back_texture

	set_move_buttons()

	display_text("a wild enemy appears")
	await textbox_closed
	action_panel.show()


func set_move_buttons() -> void:
	for i in range(move_buttons.size()):
		var btn: Button = move_buttons[i]
		if i < ally.moves.size() and ally.moves[i] != null:
			btn.text = ally.moves[i].name
			btn.disabled = false
		else:
			btn.text = "-"
			btn.disabled = true


func set_health(bar: ProgressBar, hp: int, max_hp: int) -> void:
	bar.max_value = max_hp
	bar.value = clamp(hp, 0, max_hp)


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


func play_anim_safe(anim_name: String) -> void:
	if not anim.has_animation(anim_name):
		push_warning("Missing animation: %s" % anim_name)
		return
	anim.play(anim_name)
	await anim.animation_finished


# ----------------------------
# Move helpers (called by Move.use)
# ----------------------------

func is_ally(mon: Resource) -> bool:
	return mon == ally


func get_current_health(mon: Resource) -> int:
	return current_player_health if is_ally(mon) else current_enemy_health


func set_current_health(mon: Resource, value: int) -> void:
	if is_ally(mon):
		current_player_health = value
	else:
		current_enemy_health = value


func get_max_health(mon: Resource) -> int:
	return ally.health if is_ally(mon) else enemy.health


func update_health_bar(mon: Resource) -> void:
	if is_ally(mon):
		set_health(ally_bar, current_player_health, ally.health)
	else:
		set_health(enemy_bar, current_enemy_health, enemy.health)


func apply_damage(target: Resource, amount: int) -> void:
	var target_is_ally := is_ally(target)

	var hp := get_current_health(target)
	hp = max(0, hp - amount)
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


func check_battle_end() -> bool:
	if current_enemy_health == 0:
		display_text("you have successfully defeated the enemy")
		await textbox_closed
		get_tree().quit()
		return true

	if current_player_health == 0:
		display_text("you have been defeated by the enemy")
		await textbox_closed
		get_tree().quit()
		return true

	return false


# ----------------------------
# Turn handling
# ----------------------------

func do_turn(move_num: int) -> void:
	action_panel.hide()
	move_panel.hide()

	if move_num < 0 or move_num >= ally.moves.size() or ally.moves[move_num] == null:
		display_text("That move slot is empty!")
		await textbox_closed
		action_panel.show()
		return

	var ally_first := ally_speed > enemy_speed or (ally_speed == enemy_speed and randf() < 0.5)

	if ally_first:
		await ally.moves[move_num].use(ally, enemy, self)
		if await check_battle_end(): return

		await enemy_turn()
		if await check_battle_end(): return
	else:
		await enemy_turn()
		if await check_battle_end(): return

		await ally.moves[move_num].use(ally, enemy, self)
		if await check_battle_end(): return

	action_panel.show()


func enemy_turn() -> void:
	if enemy.moves.is_empty():
		display_text("Enemy has no moves!")
		await textbox_closed
		return

	var move: Move = enemy.moves.pick_random()
	if move == null:
		display_text("Enemy picked an empty move slot!")
		await textbox_closed
		return

	await move.use(enemy, ally, self)


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
