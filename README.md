# 🌊 Godot Planar Reflection System

[![Godot Engine](https://img.shields.io/badge/Godot-4.4+-blue.svg)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/Version-1.0.0-green.svg)](https://github.com/yourusername/planar-reflection-system/releases)

A high-performance **planar reflection system** for Godot 4.4+ designed specifically for **3D pixel art games**, but can be used in any game.

![Water Reflection Demo](screenshots/demo_overview.png)

## ✨ Features

### 🎯 **Core Functionality**
- **Real-time planar reflections** with geometric accuracy
- **Pixel art optimized** - Works perfectly with SubViewport downscaling
- **Dual rendering system** - Separate game and editor modes
- **Layer-based filtering** - Control what objects appear in reflections
- **Custom environments** - Independent lighting for reflected scenes

### 🎮 **Advanced Controls**
- **Camera mode detection** - Automatic perspective/orthographic handling
- **Reflection offset system** - Fine-tune reflection positioning
- **LOD (Level of Detail)** - Distance-based performance optimization
- **Update frequency control** - Balance quality vs performance
- **Movement threshold detection** - Only update when camera moves

### ⚡ **Performance Optimizations**
- **Cached calculations** - Minimize redundant computations
- **Adaptive resolution** - Automatic quality scaling based on distance
- **Frame limiting** - Configurable update frequencies
- **Memory efficient** - Proper viewport and resource management

## 🎨 Visual Examples

| Feature | Preview |
|---------|---------|
| **Pixel Art Water** | ![Pixel Water](screenshots/pixel_water.png) |
| **3D Reflections** | ![3D Reflections](screenshots/3d_reflections.png) |
| **Multiple Objects** | ![Multi Objects](screenshots/multi_objects.png) |

## 🚀 Installation

### Method 1: AssetLib (Recommended)
1. Open Godot 4.4+
2. Go to **AssetLib** tab
3. Search for "Planar Reflection System"
4. Download and install

### Method 2: Manual Installation
1. Download the latest release from [Releases](https://github.com/yourusername/planar-reflection-system/releases)
2. Extract to your project's `addons/` folder:
