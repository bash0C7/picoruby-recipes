# PicoRuby Applications for ATOM Matrix ESP32

This directory contains PicoRuby applications for the ATOM Matrix ESP32 device, supporting VBT (Velocity-Based Training) measurements and LED control demonstrations.

## Core Applications

### VBT System
- **`vbt.rb`** - Memory-efficient VBT implementation with 3-axis acceleration measurement
  - Dependencies: `i2c`, `mpu6886`, `rmt`
  - Features: Real-time velocity/acceleration display, LCD output, WS2812 LED control
  - Hardware: MPU6886 sensor, 5×5 LED matrix, LCD display

### LED Demonstrations
- **`demo.rb`** - Ruby gemstone motion demo with dynamic LED patterns
  - Dependencies: `i2c`, `mpu6886`, `rmt`
  - Features: Motion-responsive ruby pattern, adaptive sensitivity
  - Hardware: MPU6886 sensor, WS2812 LEDs (GPIO27)

- **`led.rb`** - WS2812 LED control library with brightness management
  - Dependencies: `rmt`
  - Features: Brightness scaling, RGB/hex color support
  - Hardware: WS2812 LEDs (GPIO27)

### Hardware Interface
- **`lcd.rb`** - LCD display initialization and text output
  - Dependencies: `i2c`
  - Hardware: I2C LCD (address 0x3e, pins SDA:25, SCL:21)

- **`uart_app.rb`** - UART communication test application
  - Dependencies: `uart`
  - Features: Echo server, color command recognition
  - Hardware: USB serial (115200 baud)

## Development Files

### Build Configuration
- **`Gemfile`** - Bundler configuration for PC-side development
  - Dependencies: `uart` gem for serial communication testing
- **`Gemfile.lock`** - Dependency lock file (auto-generated)
- **`CLAUDE.md`** - Development guidelines and setup instructions

### Experimental/Development
- **`demo_with_lcd.rb`** - LCD-enabled demo variant
- **`demo_with_lcd_bit.rb`** - Bitwise LED demo with LCD
- **`nagara01/`** - Experimental LED control implementations
  - Contains alternative LED libraries and notification systems

### Legacy/Backup Files
- **`___app.rb`, `__app.rb`, `_app.rb`** - Application file variations
- **`nagara01_notify_caller.rb`** - Notification caller implementation
- **`uart_app.txt`** - UART application documentation
- **`demo.md`** - Demo documentation

## Hardware Dependencies

### Required Components
- **ATOM Matrix ESP32** - Main controller
- **MPU6886** - 3-axis accelerometer/gyroscope (I2C: SDA=25, SCL=21)
- **WS2812 LEDs** - 5×5 RGB LED matrix (GPIO27)
- **LCD Display** - I2C character display (address 0x3e, optional)

### Pin Configuration
```
GPIO25: I2C SDA (MPU6886, LCD)
GPIO21: I2C SCL (MPU6886, LCD)
GPIO27: WS2812 LED Data
GPIO32: UART1 TXD (Grove connector, optional)
GPIO33: UART1 RXD (Grove connector, optional)
```

## PicoRuby Modules Used

### Core I/O
- `i2c` - I2C communication
- `uart` - Serial communication
- `rmt` - RMT peripheral for precise timing (WS2812 control)

### Sensor
- `mpu6886` - MPU6886 accelerometer/gyroscope driver

## Usage Examples

### Running VBT System
```ruby
# Flash vbt.rb to device
# Displays real-time velocity and acceleration on LED matrix
# LCD shows numeric values
```

### Testing UART Communication
```ruby
# PC side (with bundler):
bundle exec irb
require 'uart'
# Connect to serial port and send commands

# Device side:
# Flash uart_app.rb
# Responds to "red", "green", "blue", "quit" commands
```

### LED Pattern Demo
```ruby
# Flash demo.rb for motion-responsive ruby pattern
# Move device to see LED pattern respond to motion
# Includes adaptive sensitivity and color changes
```

## Development Setup

Refer to `CLAUDE.md` for detailed development environment setup including Bundler configuration and .gitignore settings.