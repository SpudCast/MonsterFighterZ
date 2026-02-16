extends Move
class_name HealMove

@export var heal_amount: int

func use(attacker: Resource, defender: Resource, battle: Node) -> void:
	battle.display_text("%s used %s!" % [attacker.name, name])
	await battle.textbox_closed
	
	await battle.apply_heal(attacker, heal_amount)
	await battle.play_battle_anim("ally_healed")
