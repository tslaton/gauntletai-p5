# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Godot 4 rail shooter game project written in GDScript. It's part of a game development learning challenge focused on rapid development using AI assistance.

## Common Development Tasks

### Running the Game
- Open the project in Godot 4.4 or later
- Press F5 or click the play button to run the main scene
- The game runs in full screen mode by default

### Testing Changes
- Godot provides live reload - changes to scenes and scripts update in real-time while playing
- Use the Godot editor's debug console to see print statements and errors
- For script changes, save the file and Godot will automatically reload

### Working with GDScript
- GDScript uses Python-like syntax with indentation-based blocks
- All game objects inherit from Node or Node2D/Node3D classes
- Use `@export` to expose variables in the Godot editor
- Signals are used for event handling between nodes

## Architecture Overview

### Scene Structure
- **main.tscn**: Root scene that contains the game world
- **Player System**: Player controller with physics-based movement and shooting mechanics
  - Movement uses thrust-based physics with momentum and drag
  - Shooting system with cooldown timer
  - Crosshair targeting system
- **Enemy System**: Simple AI enemies that move toward the player
  - Enemy spawner manages enemy creation
  - Enemies have health and death mechanics
- **Combat System**: Projectile-based bullets with collision detection
- **Effects**: Explosion effects and jet exhaust visuals

### Key Technical Details
- Physics-based movement system with configurable thrust, drag, and speed limits
- Area3D nodes used for collision detection
- Timer nodes for cooldowns and spawning intervals
- Particle systems for visual effects

### Third-Party Addons
- **Terrain3D**: Full terrain system plugin located in `/addons/terrain_3d/`
  - Provides terrain editing tools and shaders
  - Has its own documentation in the addon folder

## Development Patterns

### Adding New Features
1. Create a new scene (.tscn) for visual components
2. Create an accompanying script (.gd) for behavior
3. Use Godot's node system to compose functionality
4. Connect signals for inter-node communication

### Code Conventions
- Use snake_case for variables and functions
- Use PascalCase for class names
- Place scripts next to their corresponding scenes
- Group related assets in folders (e.g., /enemies/, /projectiles/)

### Performance Considerations
- Use object pooling for frequently spawned objects (bullets, enemies)
- Limit the number of active physics bodies
- Use Area3D instead of RigidBody3D when full physics isn't needed
- Profile using Godot's built-in profiler (Debug → Profiler)

## File Organization
```
/player/          - Player controller and related systems
/enemies/         - Enemy AI and spawning
/projectiles/     - Bullets and projectile systems
/fx/              - Visual effects
/terrain/         - Terrain-related assets
/assets/          - Models, textures, and other resources
/addons/          - Third-party plugins
/demo/            - Example scenes and test content
/_docs/           - Project documentation
```

## Important Notes
- This is a learning project for rapid game development with AI assistance
- The game is designed as a rail shooter with 3D graphics
- Testing is primarily done through playtesting in the Godot editor
- No external build scripts needed - Godot handles compilation internally