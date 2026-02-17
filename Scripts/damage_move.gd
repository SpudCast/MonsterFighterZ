extends Move
class_name DamageMove

@export var move_power: int = 10
@export var anim_name: String = ""

func use(attacker: Resource, defender: Resource, battle: Node) -> void:
	battle.display_text("%s used %s!" % [attacker.name, name])
	await battle.textbox_closed
	
	await battle.apply_damage(attacker, defender, move_power, move_type)
	
	if anim_name != "":
		await battle.play_anim_safe(anim_name)
