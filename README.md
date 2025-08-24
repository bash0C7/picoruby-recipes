# PicoRuby Recipes

A collection of working code examples for PicoRuby (R2P2-ESP32) development. This repository demonstrates common coding patterns and practical implementations for Ruby on ESP32 devices.

## Overview

This project showcases how to use PicoRuby with ESP32 hardware, featuring real-world examples of:
- **Voice recognition** with Unit ASR for voice command processing
- **LED control** with WS2812 strips (internal matrix and external strips)
- **MPU6886 IMU sensor** integration for motion-responsive LED patterns
- **MIDI synthesis** with SAM2695 for musical applications
- **Distance sensing** with VL53L0X ToF sensor
- **Serial communication** over USB and Grove UART interfaces
- Memory-efficient programming techniques optimized for embedded systems

## Architecture

**Hybrid C++/Ruby System**:
- ESP-IDF framework for low-level hardware access
- PicoRuby runtime (R2P2-ESP32) for application logic
- Ruby scripts for sensor demos and LED control

**Key Components**:

*ESP32/ATOM Matrix (PicoRuby):*
- `asr.rb`: Unit ASR voice command recognition with LED feedback
- `asr_c.rb`: Object-oriented Unit ASR wrapper class with command handlers
- `led_int.rb`: Internal 5x5 LED matrix control for basic patterns
- `led_ext.rb`: External WS2812 LED strip control with motion response
- `led_j3_25.rb`: 25-LED strip control via J3 expansion port
- `led_j5_60.rb`: 60-LED strip control via J5 expansion board
- `syn.rb`: MIDI synthesizer with multi-channel chord progression
- `syn_atom.rb`: MIDI visualization on LED matrix with PC bridge
- `tof.rb`: VL53L0X distance sensor with range categorization
- `imu.rb`: MPU6886 IMU sensor data display and monitoring

*PC Side (CRuby):*
- `notify_caller.rb`: Claude Code hook notification system for development workflow

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
│   ├── R2P2-ESP32/
│   │   └── storage/home/        # Ruby application files for ESP32
│   │       ├── asr.rb          # Voice recognition demo
│   │       ├── asr_c.rb        # OOP Unit ASR wrapper class
│   │       ├── led_int.rb      # Internal 5x5 LED matrix
│   │       ├── led_ext.rb      # External LED strip (Grove)
│   │       ├── led_j3_25.rb    # 25-LED strip (J3 port)
│   │       ├── led_j5_60.rb    # 60-LED strip (J5 port)
│   │       ├── syn.rb          # MIDI synthesizer
│   │       ├── syn_atom.rb     # MIDI LED visualization
│   │       ├── tof.rb          # Distance sensor
│   │       └── imu.rb          # IMU sensor data
│   └── pc/                     # PC-side CRuby applications
│       ├── notify_caller.rb    # Claude Code hook notifier
│       ├── Gemfile            # Ruby dependencies
│       └── Gemfile.lock       # Locked versions
├── components/                  # Build directory (auto-generated)
├── build_config/                # Build configuration
│   └── xtensa-esp.rb           # Ruby gem configuration
└── Rakefile                    # Build automation
```

## Code Examples

**Voice Recognition** (`asr.rb`, `asr_c.rb`):
Unit ASR integration for voice command detection with visual LED feedback and Grove UART communication. Features both procedural (`asr.rb`) and object-oriented (`asr_c.rb`) implementations with command handler patterns.

**LED Control** (`led_int.rb`, `led_ext.rb`, `led_j3_25.rb`, `led_j5_60.rb`):
WS2812 LED control ranging from internal 5x5 matrix to external LED strips (15-60 LEDs) with motion-responsive patterns using different expansion ports.

**MIDI Synthesis** (`syn.rb`, `syn_atom.rb`):
Complete MIDI implementation featuring multi-channel synthesis, chord progressions, and real-time LED music visualization.

**Sensor Integration** (`tof.rb`, `imu.rb`):
Distance measurement with VL53L0X and IMU data monitoring with MPU6886, showcasing I2C device multiplexing.

**Development Tools** (`notify_caller.rb`):
PC-side CRuby utility for Claude Code integration, providing visual notifications and serial communication with ATOM Matrix during development workflow.

## Development Notes

- **Memory optimization**: Pre-allocated arrays and minimal dynamic allocation for embedded constraints
- **Sensor integration**: MPU6886 and VL53L0X sharing I2C bus with proper address management
- **UART communication**: Dual-mode support for USB (115200bps) and Grove (31250bps/115200bps)
- **LED control**: RMT peripheral for precise WS2812 timing with brightness safety limits
- **MIDI processing**: Binary message handling with real-time visualization capabilities
- All Ruby gems configured in `build_config/xtensa-esp.rb`

## Hardware Support

Tested with ATOM Matrix ESP32 devices featuring:
- **ESP32-PICO-D4** microcontroller (240MHz dual-core)
- **MPU6886** 6-axis IMU (I2C address 0x68)
- **5×5 WS2812** LED matrix (GPIO 27, 25 LEDs total)
- **Grove connector** for UART/I2C expansion (GPIO 26, 32)
- **USB-C interface** for programming and serial communication
- **Built-in button** (GPIO 39) for user input

**Compatible peripherals**:
- Unit ASR (CI-03T) voice recognition module
- MIDI Unit (SAM2695) synthesizer module  
- VL53L0X ToF distance sensor (I2C address 0x29)
- External WS2812 LED strips (15-60 LEDs)

**Expansion ports**:
- **Grove connector** (GPIO 26, 32): UART/I2C communication
- **J3 port** (GPIO 25, 21): I2C devices (shares bus with MPU6886)
- **J5 port** (GPIO 19, 22): Additional GPIO/UART for LED strips

## License

This project serves as educational examples for PicoRuby development on ESP32 platforms.