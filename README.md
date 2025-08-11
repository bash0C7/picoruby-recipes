# PicoRuby Recipes

A collection of working code examples for PicoRuby (R2P2-ESP32) development. This repository demonstrates common coding patterns and practical implementations for Ruby on ESP32 devices.

## Overview

This project showcases how to use PicoRuby with ESP32 hardware, featuring real-world examples of:
- LED control with WS2812 strips using RMT peripheral
- MPU6886 IMU sensor integration for motion detection
- Memory-efficient programming techniques
- Hardware abstraction patterns in Ruby

## Architecture

**Hybrid C++/Ruby System**:
- ESP-IDF framework for low-level hardware access
- PicoRuby runtime (R2P2-ESP32) for application logic
- Ruby scripts for sensor demos and LED control

**Key Components**:
- `vbt.rb`: Velocity-based training implementation with motion analysis
- `demo.rb`: Interactive LED patterns responding to device movement
- `led.rb`: WS2812 LED strip control library with brightness management

## Quick Start

**Prerequisites**:
- ESP-IDF installed at `$HOME/esp/esp-idf/`
- Homebrew with OpenSSL (macOS)
- ATOM Matrix ESP32 device

**Setup**:
```bash
rake init          # Initialize project and dependencies
rake build         # Build for ESP32
rake flash         # Flash to device
```

**Development Commands**:
```bash
rake -T            # List all available tasks
rake update        # Update R2P2-ESP32 dependencies
rake cleanbuild    # Clean rebuild
rake check_env     # Verify environment setup
```

## Project Structure

```
picoruby-recipes/
├── src_components/              # Source components (tracked in git)
│   └── R2P2-ESP32/
│       └── storage/home/        # Ruby application files
├── components/                  # Build directory (auto-generated)
├── build_config/                # Build configuration
│   └── xtensa-esp.rb           # Ruby gem configuration
└── Rakefile                    # Build automation
```

## Code Examples

**LED Control**:
Ruby scripts demonstrate efficient WS2812 control using the RMT peripheral for precise timing.

**Motion Detection**:
MPU6886 sensor integration showcases real-time motion analysis with memory-optimized calculations.

**VBT System**:
Complete velocity-based training implementation using squared acceleration values to avoid expensive sqrt operations.

## Development Notes

- Memory optimization is critical - use pre-allocated arrays and avoid dynamic allocation
- Sensor calibration uses squared values for performance
- LED patterns leverage RMT peripheral for precise timing control
- All Ruby gems configured in `build_config/xtensa-esp.rb`

## Hardware Support

Tested with ATOM Matrix ESP32 devices featuring:
- ESP32-PICO-D4 microcontroller
- MPU6886 6-axis IMU
- 5×5 WS2812 LED matrix
- Built-in button and USB-C interface

## License

This project serves as educational examples for PicoRuby development on ESP32 platforms.