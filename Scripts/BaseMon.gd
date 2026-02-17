extends Resource

@export var name: String = "pokemon"
@export var types: Array[TypeChart.Type] = [TypeChart.Type.NORMAL]
@export_range(1, 100) var level: int

@export var texture: Texture2D
@export var back_texture: Texture2D

@export var base_health: int
@export var base_attack: int
@export var base_defense: int
@export var base_speed: int

@export var IV_health: int
@export var IV_attack: int
@export var IV_defense: int
@export var IV_speed: int

@export var EV_health: int
@export var EV_attack: int
@export var EV_defense: int
@export var EV_speed: int

@export var moves: Array[Move] = []

