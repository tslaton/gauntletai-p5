extends Node

const DEFAULT_FLYING_HEIGHT = 20.0

var mars_dust_effect: Node3D

func toggle_mars_dust():
	if mars_dust_effect and mars_dust_effect.has_method("toggle_dust"):
		mars_dust_effect.toggle_dust()