extends Control

signal textbox_closed

@export var enemy: Resource  # ideally your BaseMon type
@export var ally: Resource   # ideally your BaseMon type

var current_player_health: int = 0
var current_enemy_health: int = 0

var ally_speed: int = 0
var enemy_speed: int = 0


func _ready() -> void:
	randomize() # for tie coin-flips + any rand usage

	# Setup UI
	$Textbox.hide()
	$ActionPanel.hide()
	$MovePanel.hide()

	# Load data into UI
	current_player_health = ally.health
	current_enemy_health = enemy.health

	ally_speed = ally.speed
	enemy_speed = enemy.speed

	set_health($EnemyContainer/EnemyHealth, current_enemy_health, enemy.health)
	set_health($AllyContainer/AllyHealth, current_player_health, ally.health)

	$EnemyContainer/Enemy.texture = enemy.texture
	$AllyContainer/Ally.texture = ally.texture

	set_move_buttons()

	# Intro
	display_text("a wild enemy appears")
	await textbox_closed
	$ActionPanel.show()

func play_battle_anim(anim_name: String) -> void:
	$AnimationPlayer.play(anim_name)
	await $AnimationPlayer.animation_finished

func set_move_buttons() -> void:
	var buttons: Array = $"MovePanel/Actions".get_children()

	for i in range(buttons.size()):
		var btn = buttons[i]
		if i < ally.moves.size() and ally.moves[i] != null:
			btn.text = ally.moves[i].name
			btn.disabled = false
		else:
			btn.text = "-"
			btn.disabled = true


func set_health(progress_bar, health: int, max_health: int) -> void:
	progress_bar.value = health
	progress_bar.max_value = max_health

func close_textbox() -> void:
	if not $Textbox.visible:
		return
	$Textbox.hide()
	emit_signal("textbox_closed")


#-------------------------------------
# Input Handler
#-------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not $Textbox.visible:
		return

	if event.is_action_pressed("ui_accept"):
		$Textbox.hide()
		emit_signal("textbox_closed")

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		$Textbox.hide()
		emit_signal("textbox_closed")


func display_text(text: String) -> void:
	$Textbox.show()
	$Textbox/Label.text = text


# ----------------------------
# Helpers for Move.use() scripts
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
		set_health($AllyContainer/AllyHealth, current_player_health, ally.health)
	else:
		set_health($EnemyContainer/EnemyHealth, current_enemy_health, enemy.health)


# Call these from your DamageMove / HealMove scripts
func apply_damage(target: Resource, amount: int) -> void:
	var hp := get_current_health(target)
	hp = max(0, hp - amount)
	set_current_health(target, hp)
	update_health_bar(target)

	# Play the correct animation for who got hit
	if is_ally(target):
		$AnimationPlayer.play("player_damaged")
	else:
		$AnimationPlayer.play("enemy_damaged")
	await $AnimationPlayer.animation_finished


func apply_heal(target: Resource, amount: int) -> void:
	var hp := get_current_health(target)
	var max_hp := get_max_health(target)
	hp = min(max_hp, hp + amount)
	set_current_health(target, hp)
	update_health_bar(target)

	# Optional: if you have heal animations, use them.
	# If you don't, you can remove this animation block safely.
	if is_ally(target) and $AnimationPlayer.has_animation("player_healed"):
		$AnimationPlayer.play("player_healed")
		await $AnimationPlayer.animation_finished
	elif (not is_ally(target)) and $AnimationPlayer.has_animation("enemy_healed"):
		$AnimationPlayer.play("enemy_healed")
		await $AnimationPlayer.animation_finished


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
	$ActionPanel.hide()
	$MovePanel.hide()

	# Validate move slot
	if move_num < 0 or move_num >= ally.moves.size() or ally.moves[move_num] == null:
		display_text("That move slot is empty!")
		await textbox_closed
		$ActionPanel.show()
		return

	# Decide who goes first
	var ally_first: bool
	if ally_speed > enemy_speed:
		ally_first = true
	elif enemy_speed > ally_speed:
		ally_first = false
	else:
		ally_first = randf() < 0.5 # speed tie coin flip

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

	$ActionPanel.show()


func enemy_turn() -> void:
	if enemy.moves.is_empty():
		display_text("Enemy has no moves!")
		await textbox_closed
		return

	var move: Move = enemy.moves.pick_random()
	await move.use(enemy, ally, self)
	if not $ActionPanel.show():
		$ActionPanel.show()


# ----------------------------
# Buttons
# ----------------------------

func _on_run_pressed() -> void:
	display_text("got away safely")
	await textbox_closed
	get_tree().quit()

func _on_attack_pressed() -> void:
	$ActionPanel.hide()
	$MovePanel.show()

func _on_move_1_pressed() -> void: await do_turn(0)
func _on_move_2_pressed() -> void: await do_turn(1)
func _on_move_3_pressed() -> void: await do_turn(2)
func _on_move_4_pressed() -> void: await do_turn(3)
