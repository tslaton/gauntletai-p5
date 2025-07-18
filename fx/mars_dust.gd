@tool
extends Node3D

@export var enabled_in_editor: bool = false:
	set(value):
		enabled_in_editor = value
		if Engine.is_editor_hint():
			set_dust_visible(value)

@export var enabled_in_game: bool = true
@export_category("Fog Properties")
@export var fog_color: Color = Color(0.8, 0.3, 0.15, 1.0):
	set(value):
		fog_color = value
		if environment and (enabled_in_editor or not Engine.is_editor_hint()):
			environment.fog_light_color = fog_color
@export var fog_density: float = 0.02:
	set(value):
		fog_density = value
		if environment and (enabled_in_editor or not Engine.is_editor_hint()):
			environment.fog_density = fog_density
@export var fog_height: float = 30.0:
	set(value):
		fog_height = value
		if environment and (enabled_in_editor or not Engine.is_editor_hint()):
			environment.fog_height = fog_height
@export var fog_height_falloff: float = 0.2:
	set(value):
		fog_height_falloff = value
		if environment and (enabled_in_editor or not Engine.is_editor_hint()):
			environment.fog_height_density = fog_height_falloff

var environment: Environment
var original_fog_enabled: bool = false
var original_fog_density: float = 0.0
var original_fog_color: Color = Color.WHITE
var has_stored_original_settings: bool = false

func _ready():
	setup_fog_effect()
	
	# Use call_deferred to ensure environment is fully loaded
	if Engine.is_editor_hint():
		# In editor, respect the checkbox
		call_deferred("set_dust_visible", enabled_in_editor)
	else:
		# In game, start with Mars dust fog enabled by default
		if enabled_in_game:
			call_deferred("set_dust_visible", true)

func setup_fog_effect():
	# Find or create environment
	var world_env
	if Engine.is_editor_hint():
		# In editor, look for WorldEnvironment in the scene
		var parent = get_parent()
		while parent:
			world_env = parent.get_node_or_null("WorldEnvironment")
			if world_env:
				break
			parent = parent.get_parent()
	else:
		# In game, use the direct path
		world_env = get_node_or_null("/root/Main/WorldEnvironment")
	
	if world_env and world_env.environment:
		environment = world_env.environment

func set_dust_visible(visible: bool):
	# Toggle environment fog
	if environment:
		if visible:
			environment.fog_enabled = true
			environment.fog_light_color = fog_color
			environment.fog_light_energy = 0.5
			environment.fog_sun_scatter = 0.2
			environment.fog_density = fog_density
			environment.fog_aerial_perspective = 0.5
			environment.fog_height = fog_height
			environment.fog_height_density = fog_height_falloff
		else:
			# Always disable fog when Mars dust is off
			environment.fog_enabled = false

func toggle_dust():
	set_dust_visible(not is_dust_visible())

func is_dust_visible() -> bool:
	if environment:
		return environment.fog_enabled and environment.fog_light_color == fog_color
	return false
