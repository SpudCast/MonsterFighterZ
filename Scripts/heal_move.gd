extends Move
class_name HealMove

@export var heal_amount: int = 0

func use(attacker: Resource, defender: Resource, battle: Node) -> void:
	battle.display_text("%s used %s!" % [attacker.name, name])
	await battle.textbox_closed

	await battle.apply_heal(attacker, heal_amount)

	var anim_name := "player_healed" if battle.is_ally(attacker) else "enemy_healed"
	await battle.play_anim_safe(anim_name)
