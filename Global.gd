extends Node

const DEFAULT_FLYING_HEIGHT = 20.0

# Difficulty settings
enum Difficulty { EASY, MEDIUM, HARD }
var current_difficulty: Difficulty = Difficulty.MEDIUM

# Player health based on difficulty
const PLAYER_HEALTH = {
	Difficulty.EASY: 500,
	Difficulty.MEDIUM: 350,
	Difficulty.HARD: 200
}

var mars_dust_effect: Node3D

func toggle_mars_dust():
	if mars_dust_effect and mars_dust_effect.has_method("toggle_dust"):
		mars_dust_effect.toggle_dust()

func get_player_health() -> int:
	return PLAYER_HEALTH[current_difficulty]