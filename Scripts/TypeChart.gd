extends Node

# -----------------------------
# TYPES
# -----------------------------
enum Type {
	NORMAL,
	FIRE,
	WATER,
	GRASS,
	ELECTRIC,
	ICE,
	FIGHTING,
	POISON,
	GROUND,
	FLYING,
	PSYCHIC,
	BUG,
	ROCK,
	GHOST,
	DRAGON,
	DARK,
	STEEL,
	FAIRY
}

# -----------------------------
# TYPE EFFECTIVENESS
# Only store differences from 1.0
# -----------------------------
const EFFECT := {

	Type.NORMAL: {
		Type.ROCK: 0.5,
		Type.GHOST: 0.0,
		Type.STEEL: 0.5
	},

	Type.FIRE: {
		Type.GRASS: 2.0,
		Type.ICE: 2.0,
		Type.BUG: 2.0,
		Type.STEEL: 2.0,
		Type.FIRE: 0.5,
		Type.WATER: 0.5,
		Type.ROCK: 0.5,
		Type.DRAGON: 0.5
	},

	Type.WATER: {
		Type.FIRE: 2.0,
		Type.GROUND: 2.0,
		Type.ROCK: 2.0,
		Type.WATER: 0.5,
		Type.GRASS: 0.5,
		Type.DRAGON: 0.5
	},

	Type.GRASS: {
		Type.WATER: 2.0,
		Type.GROUND: 2.0,
		Type.ROCK: 2.0,
		Type.FIRE: 0.5,
		Type.GRASS: 0.5,
		Type.POISON: 0.5,
		Type.FLYING: 0.5,
		Type.BUG: 0.5,
		Type.DRAGON: 0.5,
		Type.STEEL: 0.5
	},

	Type.ELECTRIC: {
		Type.WATER: 2.0,
		Type.FLYING: 2.0,
		Type.ELECTRIC: 0.5,
		Type.GRASS: 0.5,
		Type.DRAGON: 0.5,
		Type.GROUND: 0.0
	},

	Type.ICE: {
		Type.GRASS: 2.0,
		Type.GROUND: 2.0,
		Type.FLYING: 2.0,
		Type.DRAGON: 2.0,
		Type.FIRE: 0.5,
		Type.WATER: 0.5,
		Type.ICE: 0.5,
		Type.STEEL: 0.5
	},

	Type.FIGHTING: {
		Type.NORMAL: 2.0,
		Type.ROCK: 2.0,
		Type.STEEL: 2.0,
		Type.ICE: 2.0,
		Type.DARK: 2.0,
		Type.FLYING: 0.5,
		Type.POISON: 0.5,
		Type.BUG: 0.5,
		Type.PSYCHIC: 0.5,
		Type.FAIRY: 0.5,
		Type.GHOST: 0.0
	},

	Type.POISON: {
		Type.GRASS: 2.0,
		Type.FAIRY: 2.0,
		Type.POISON: 0.5,
		Type.GROUND: 0.5,
		Type.ROCK: 0.5,
		Type.GHOST: 0.5,
		Type.STEEL: 0.0
	},

	Type.GROUND: {
		Type.FIRE: 2.0,
		Type.ELECTRIC: 2.0,
		Type.POISON: 2.0,
		Type.ROCK: 2.0,
		Type.STEEL: 2.0,
		Type.GRASS: 0.5,
		Type.BUG: 0.5,
		Type.FLYING: 0.0
	},

	Type.FLYING: {
		Type.GRASS: 2.0,
		Type.FIGHTING: 2.0,
		Type.BUG: 2.0,
		Type.ELECTRIC: 0.5,
		Type.ROCK: 0.5,
		Type.STEEL: 0.5
	},

	Type.PSYCHIC: {
		Type.FIGHTING: 2.0,
		Type.POISON: 2.0,
		Type.PSYCHIC: 0.5,
		Type.STEEL: 0.5,
		Type.DARK: 0.0
	},

	Type.BUG: {
		Type.GRASS: 2.0,
		Type.PSYCHIC: 2.0,
		Type.DARK: 2.0,
		Type.FIRE: 0.5,
		Type.FIGHTING: 0.5,
		Type.POISON: 0.5,
		Type.FLYING: 0.5,
		Type.GHOST: 0.5,
		Type.STEEL: 0.5,
		Type.FAIRY: 0.5
	},

	Type.ROCK: {
		Type.FIRE: 2.0,
		Type.ICE: 2.0,
		Type.FLYING: 2.0,
		Type.BUG: 2.0,
		Type.FIGHTING: 0.5,
		Type.GROUND: 0.5,
		Type.STEEL: 0.5
	},

	Type.GHOST: {
		Type.PSYCHIC: 2.0,
		Type.GHOST: 2.0,
		Type.DARK: 0.5,
		Type.NORMAL: 0.0
	},

	Type.DRAGON: {
		Type.DRAGON: 2.0,
		Type.STEEL: 0.5,
		Type.FAIRY: 0.0
	},

	Type.DARK: {
		Type.PSYCHIC: 2.0,
		Type.GHOST: 2.0,
		Type.FIGHTING: 0.5,
		Type.DARK: 0.5,
		Type.FAIRY: 0.5
	},

	Type.STEEL: {
		Type.ICE: 2.0,
		Type.ROCK: 2.0,
		Type.FAIRY: 2.0,
		Type.FIRE: 0.5,
		Type.WATER: 0.5,
		Type.ELECTRIC: 0.5,
		Type.STEEL: 0.5
	},

	Type.FAIRY: {
		Type.FIGHTING: 2.0,
		Type.DRAGON: 2.0,
		Type.DARK: 2.0,
		Type.FIRE: 0.5,
		Type.POISON: 0.5,
		Type.STEEL: 0.5
	}
}

# -----------------------------
# MULTIPLIER FUNCTION
# -----------------------------
static func get_multiplier(move_type: int, defender_types: Array[int]) -> float:
	var multiplier := 1.0
	var row: Dictionary = EFFECT.get(move_type, {})

	for t in defender_types:
		multiplier *= float(row.get(t, 1.0))

	return multiplier


# -----------------------------
# STAB BONUS
# -----------------------------
static func get_stab(move_type: int, attacker_types: Array[int]) -> float:
	return 1.5 if attacker_types.has(move_type) else 1.0


# -----------------------------
# Optional helper (great for UI)
# -----------------------------
static func get_effectiveness_text(mult: float) -> String:
	if mult == 0:
		return "It doesn't affect the target..."
	elif mult == 4.0:
		return "It's extremely effective!"
	elif mult == 2.0:
		print(mult)
		return "It's super effective!"
	elif mult < 1.0:
		return "It's not very effective..."
	return ""
