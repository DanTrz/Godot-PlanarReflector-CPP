# 🌊 Godot Planar Reflection System

[![Godot Engine](https://img.shields.io/badge/Godot-4.4+-blue.svg)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/Version-1.0.0-green.svg)](https://github.com/yourusername/planar-reflection-system/releases)

A high-performance **planar reflection system** for Godot 4.4+ designed specifically for **3D pixel art games**, but can be used in any game.

![Reflection Demo](screenshots/demo_overview.png)

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
- **Cached calculations** - Minimize redundant computations

## 🎨 Visual Examples

| Feature | Preview |
|---------|---------|
| **Pixel Art Water** | ![Pixel Water](screenshots/pixel_water.png) |
| **3D Reflections** | ![3D Reflections](screenshots/3d_reflections.png) |
| **Multiple Objects** | ![Multi Objects](screenshots/multi_objects.png) |

## 🚀 Installation

### Method 1: Manual Installation
1. Download the latest release code from Github
2. Just copy the entire  `addons/` folder to your Godot res:// folder.
3. If you already have a `addons/` folder, all you need is to paste the `PlanarReflectorCpp/` folder in there

## Method 2: AssetLib (WiP - coming soon)
