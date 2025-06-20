# 🌊 Godot C++ Planar Reflection System 
![icons_reflection](https://github.com/user-attachments/assets/bc76be0d-0a7f-4f9c-a380-4860a81761ef)

[![Godot Engine](https://img.shields.io/badge/Godot-4.4+-blue.svg)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/Version-1.0.0-green.svg)](https://github.com/yourusername/planar-reflection-system/releases)

A high-performance **planar reflection system** for Godot 4.4+ designed specifically for **3D pixel art games**, but can be used in any game.

![Reflection Demo](https://github.com/user-attachments/assets/fa956dd3-b951-4d58-9f8d-aa412fde0da9)

## ✨ Features

### 🎯 **Core Functionality**
- **Real-time planar reflections** with geometric accuracy
- **Very performant** written in C++ via GDExtensions
- **Pixel art optimized** - Works perfectly with SubViewport downscaling
- **Dual rendering system** - Separate game and editor modes
- **Layer-based filtering** - Control what objects appear in reflections
- **Custom environments** - Independent lighting for reflected scenes

### 🎮 **Reflection & Performance Features**
- **Camera mode detection** - Automatic perspective/orthographic handling
- **Reflection offset system** - Fine-tune reflection positioning
- **LOD (Level of Detail)** - Distance-based performance optimization
- **Update frequency control** - Balance quality vs performance
- **Movement threshold detection** - Only update when camera moves
- **Configurable reflection layers** - You can define what Visibility Layers get reflection
- **Cached calculations** - Minimize redundant computations

## 🚀 Installation

### Method 1: Manual Installation
1. Download the latest release code from Github
3. Just copy the entire  `addons/` folder to your Godot res:// folder.
4. If you already have a `addons/` folder, all you need is to paste the `PlanarReflectorCpp/` folder in there
5. Enable the plugin in the Godot settings -> You might need to reload your project
6. You can download/Clone the entire Git Repo that comes with a DemoScene to see the base configuration applied

### Method 2: AssetLib (WiP - coming soon)

## 🎮 General usage:
1. Add the PlanarReflectorCpp node to your scene
2. Add a PlanarMesh to it
3. Add the provided BaseMaterial and BaseShader to it (see: addons/PlanarReflectorCpp/SupportFiles/)
4. Make sure your objects are set the the Visibility Layer that matches the "Reflection layer" in the PlanarReflector
5. Add custom enviroment (ideally without BG or BG COlor) and configure the PlanarReflector exported properties.
6. Check that your lights are also in the correct layer and that your Main Camera is assigned (and the Camera CullMasks match the layers)
7. Run your game
8. To see reflections working in the editor, make sure you enable the plugin and "click" in the 3D scene, selecting the planar node in the scene (will refresh it)


## 🔧 Technical Constraints
- **Planar surfaces only** - Works best with flat surfaces
- **No "below surface" object filtering** - It will show reflection of "underwater" elements for example. To workaround this, use cull-masks to ignore these objects.
- **Requires Plugin enabled for editor** - To see reflections in the Editor the plugin must be active
