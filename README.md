🌊 Godot Planar Reflection System
Show Image
Show Image
Show Image
A high-performance planar reflection system for Godot 4.4+ designed specifically for 3D pixel art games. Create stunning water reflections that work seamlessly with low-resolution rendering pipelines while maintaining professional visual quality.
Show Image
✨ Features
🎯 Core Functionality

Real-time planar reflections with geometric accuracy
Pixel art optimized - Works perfectly with SubViewport downscaling
Dual rendering system - Separate game and editor modes
Layer-based filtering - Control what objects appear in reflections
Custom environments - Independent lighting for reflected scenes

🎮 Advanced Controls

Camera mode detection - Automatic perspective/orthographic handling
Reflection offset system - Fine-tune reflection positioning
LOD (Level of Detail) - Distance-based performance optimization
Update frequency control - Balance quality vs performance
Movement threshold detection - Only update when camera moves

⚡ Performance Optimizations

Cached calculations - Minimize redundant computations
Adaptive resolution - Automatic quality scaling based on distance
Frame limiting - Configurable update frequencies
Memory efficient - Proper viewport and resource management

🎨 Visual Examples
FeaturePreviewPixel Art WaterShow Image3D ReflectionsShow ImageMultiple ObjectsShow Image
🚀 Installation
Method 1: AssetLib (Recommended)

Open Godot 4.4+
Go to AssetLib tab
Search for "Planar Reflection System"
Download and install

Method 2: Manual Installation

Download the latest release from Releases
Extract to your project's addons/ folder:
your_project/
├── addons/
│   └── planar_reflection_system/
│       ├── plugin.cfg
│       ├── plugin.gd
│       └── ...

Enable the plugin in Project Settings > Plugins

Method 3: Git Submodule
bashcd your_project
git submodule add https://github.com/yourusername/planar-reflection-system.git addons/planar_reflection_system
📖 Quick Start
1. Basic Setup
gdscript# Add PlanarReflectorCPP node to your scene
var reflector = PlanarReflectorCPP.new()
add_child(reflector)

# Assign your main camera
reflector.main_camera = $Camera3D

# Configure reflection layers (optional)
reflector.reflection_layers = 1  # Only layer 1 objects
2. Water Shader Setup
Apply the included water shader to your water mesh:
gdscript# Load the shader material
var water_material = preload("res://addons/planar_reflection_system/shaders/planar_reflection_ortho_working_improved.gdshader")
$WaterMesh.set_surface_material(0, water_material)
3. Pixel Art Configuration
For pixel art games using SubViewport:
gdscriptreflector.ortho_scale_multiplier = 1.0
reflector.ortho_uv_scale = 1.0
reflector.auto_detect_camera_mode = true
🛠️ Configuration Options
📷 Camera Controls
gdscript# Orthographic camera scaling
reflector.ortho_scale_multiplier = 1.0
reflector.ortho_uv_scale = 1.0
reflector.auto_detect_camera_mode = true
🎭 Layer Management
gdscript# Control which objects appear in reflections
reflector.reflection_layers = 5  # Layers 1 and 3 (binary: 101)
reflector.use_custom_environment = true
reflector.custom_environment = your_environment_resource
🎯 Reflection Offset
gdscript# Fine-tune reflection positioning
reflector.enable_reflection_offset = true
reflector.reflection_offset_position = Vector3(0, 2, 0)
reflector.reflection_offset_rotation = Vector3(0, 45, 0)
reflector.offset_blend_mode = 0  # 0=Add, 1=Multiply, 2=Screen Space
⚡ Performance Tuning
gdscript# Optimize for your target framerate
reflector.update_frequency = 2  # Update every 2 frames
reflector.use_lod = true
reflector.lod_distance_near = 10.0
reflector.lod_distance_far = 50.0
reflector.lod_resolution_multiplier = 0.5
🎯 Use Cases
✅ Perfect For:

Pixel art water reflections in 3D games
Architectural visualization with realistic water
Stylized games requiring clean reflection effects
Low-poly environments with water features
Indie games needing professional water quality

🎮 Game Types:

Action RPGs with water exploration
Puzzle games using reflection mechanics
Adventure games with scenic water areas
Strategy games with naval elements
Simulation games featuring water bodies

⚠️ Limitations
🔧 Technical Constraints

Planar surfaces only - Works best with flat water
Single reflection plane per reflector instance
No underwater object filtering (requires GDExtension for oblique clipping)
Performance scales with reflection resolution

🎨 Visual Limitations

No screen-space reflections mixing
Limited to assigned layers for reflection content
Editor preview may differ from game rendering
Requires shader knowledge for advanced customization

📊 Performance Considerations

Additional draw calls for reflection viewport
Memory usage increases with resolution
Frame rate impact depends on scene complexity
Mobile performance may require aggressive LOD

🏗️ Architecture
🧩 Core Components
PlanarReflectorCPP (C++ Node)
├── Editor Mode
│   ├── Editor Viewport & Camera
│   └── Plugin Integration
├── Game Mode
│   ├── Game Viewport & Camera
│   └── Runtime Optimization
└── Shared Systems
    ├── Offset Calculations
    ├── LOD Management
    └── Shader Integration
🔄 Rendering Pipeline

Main Camera Setup - Detect camera mode and properties
Reflection Calculation - Compute mirrored camera position
Viewport Rendering - Render reflection scene to texture
Shader Application - Apply reflection texture to water material
Performance Optimization - LOD and update frequency control

🛡️ Troubleshooting
❓ Common Issues
Reflection Not Appearing
gdscript# Check these settings:
reflector.is_active = true
reflector.main_camera = $YourCamera3D
reflector.reflection_layers = 1  # Ensure objects are on correct layers
Performance Problems
gdscript# Optimize with these settings:
reflector.update_frequency = 3
reflector.use_lod = true
reflector.lod_resolution_multiplier = 0.25
Editor Preview Issues

Plugin automatically handles editor mode
Reflections may look different in editor vs game
Use "Remote Debug" for accurate game preview

🐛 Debug Tips

Check Console Output for initialization messages
Verify Layer Assignments on your objects
Test with Simple Scenes first
Monitor Performance Tab for frame drops

🤝 Contributing
We welcome contributions! Here's how to get started:
🚀 Development Setup
bashgit clone https://github.com/yourusername/planar-reflection-system.git
cd planar-reflection-system
# Open project in Godot 4.4+
📋 Contribution Guidelines

Follow Godot C++ style guide
Add tests for new features
Update documentation for API changes
Use clear commit messages

🎯 Areas for Contribution

Underwater object filtering (GDExtension implementation)
Multiple reflection planes support
Performance optimizations
Additional shader effects
Mobile platform optimization

📜 License
This project is licensed under the MIT License - see the LICENSE file for details.
Copyright (c) 2024 [Your Name]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...
🙏 Acknowledgments

Eric Lengyel - Oblique projection mathematics
JFons - Original Godot mirror implementation inspiration
Godot Community - Feedback and testing
David Holland - 3D pixel art rendering techniques

🔗 Links

Documentation: Wiki
Bug Reports: Issues
Feature Requests: Discussions
Godot Asset Library: Asset Store Page
