extends Resource
class_name Move

@export var name: String
@export var move_type: TypeChart.Type = TypeChart.Type.NORMAL

func use(attacker: Resource, defender: Resource, battle:Node) -> void:
	pass
