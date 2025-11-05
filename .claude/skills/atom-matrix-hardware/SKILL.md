---
name: atom-matrix-hardware
description: ATOM Matrix ESP32 hardware pinout, GPIO allocation, MPU6886 accelerometer, WS2812 LED control, button inputs, UART/I2C protocols, and hardware initialization. Use when working with GPIO, pins, sensors, LED wiring, button logic, or hardware initialization.
---

# ATOM Matrix (ESP32-PICO-D4) Hardware Reference

## Quick Pinout Reference

```
ATOM Matrix ESP32-PICO-D4 (25mm cube)

Top Surface (5x5 LED Matrix):
  GPIO 22 ─────→ WS2812 Data Line (60 LEDs addressable)

Left Edge:
  GPIO 25 ─────→ I2C SDA (MPU6886 accelerometer)
  GPIO 21 ─────→ I2C SCL (MPU6886 accelerometer)

Right Edge:
  GPIO 39 ─────→ Button Input (Crash Cymbal Trigger)

Bottom Connectors:
  GPIO RX/TX ──→ UART0 (PC communication, 115200 bps)
  GPIO 23/33 ──→ MIDI Output (Optional, 31250 bps)
```

---

## GPIO Pin Allocations

| GPIO | Purpose | Direction | Protocol | Baud/Freq | Notes |
|------|---------|-----------|----------|-----------|-------|
| 22 | WS2812 LED Data | OUT | 1-Wire (serial) | ~800kHz | 60 LEDs, addressable |
| 25 | I2C SDA | I/O | I2C | 400kHz | MPU6886 accelerometer |
| 21 | I2C SCL | I/O | I2C | 400kHz | MPU6886 accelerometer |
| 39 | Button Input | IN | GPIO | - | Active LOW (pressed = GND) |
| RX0 | UART RX | IN | UART | 115200 bps | PC communication |
| TX0 | UART TX | OUT | UART | 115200 bps | PC communication |
| 23 | MIDI TX (Optional) | OUT | UART | 31250 bps | Serial MIDI output |
| 33 | MIDI RX (Optional) | IN | UART | 31250 bps | Serial MIDI input |

**Notes**:
- GPIO 6-11: **Reserved** for internal flash (do not use)
- GPIO 34-39: **Input only** (no output capable)
- GPIO 39 is a capacitive touch pin but configured as digital input for button

---

## WS2812 LED Strip (60 LEDs)

### Physical Layout
- **Type**: WS2812B (NeoPixel-compatible) RGB addressable LEDs
- **Count**: 60 individual LEDs
- **Control**: Single GPIO 22 (data line)
- **Power**: 5V external (not from GPIO)
- **Data Format**: GRB (Green, Red, Blue byte order, NOT RGB)

### Wiring
```
ATOM Matrix GPIO 22 ─────────────→ DIN (WS2812 Data In)
External 5V ─────────────────────→ VCC (WS2812 Power)
GND ──────────────────────────────→ GND (Common Ground)
```

### LED Addressing
```ruby
# LED positions (0-59)
# Typically arranged in a 5x5 matrix or linear strip

# Set single LED color (GRB format)
LED.set(index, green, red, blue)  # 0-255 each

# Examples:
LED.set(0, 0, 255, 0)      # LED 0: Red
LED.set(1, 255, 0, 0)      # LED 1: Green
LED.set(2, 0, 0, 255)      # LED 2: Blue
LED.set(3, 255, 255, 255)  # LED 3: White (all channels)

# Update all LEDs at once
LED.show()
```

### Power Considerations
- Each LED: ~60mA max (all channels 255)
- All 60 LEDs: ~3.6A theoretical maximum
- **Recommendation**: 5A external power supply
- Never power from GPIO pins (max 40mA per pin)

### Common Issues & Solutions
| Problem | Cause | Solution |
|---------|-------|----------|
| LEDs flickering | Insufficient power | Use external 5A PSU, check GND connection |
| Wrong colors | GRB vs RGB confusion | Use `LED.set(idx, green, red, blue)` |
| Some LEDs dark | LED burnout or wiring break | Check continuity, replace LED if needed |
| All LEDs off | GPIO 22 not initialized | Call LED initialization code |

---

## MPU6886 Accelerometer (I2C)

### Specifications
- **Type**: 6-axis IMU (Accelerometer + Gyroscope)
- **Address**: 0x68 (7-bit I2C address)
- **I2C Bus**: GPIO 25 (SDA), GPIO 21 (SCL)
- **Speed**: 400kHz I2C standard
- **Acceleration Range**: ±16g (default), selectable to ±2g, ±4g, ±8g
- **Gyroscope Range**: ±2000°/s (default)

### Initialization (PicoRuby)
```ruby
# Setup I2C
i2c = I2C.new(0, 25, 21)  # I2C 0, SDA=GPIO25, SCL=GPIO21

# Wake up MPU6886 (clear sleep bit, register 0x6B)
i2c.write(0x68, [0x6B, 0x00])

# Set accelerometer scale to ±16g (register 0x1C)
i2c.write(0x68, [0x1C, 0x00])

# Read accelerometer data (6 bytes: 3 axes × 2 bytes each)
# Register 0x3B onwards for accel X, Y, Z
data = i2c.read(0x68, 0x3B, 6)
```

### Reading Acceleration Data
```ruby
# Raw data: 6 bytes (2 bytes per axis)
accel_x = (data[0] << 8) | data[1]  # Combine high and low bytes
accel_y = (data[2] << 8) | data[3]
accel_z = (data[4] << 8) | data[5]

# Convert to signed 16-bit (two's complement)
accel_x = accel_x > 32767 ? accel_x - 65536 : accel_x
accel_y = accel_y > 32767 ? accel_y - 65536 : accel_y
accel_z = accel_z > 32767 ? accel_z - 65536 : accel_z

# Divide by sensitivity (16384 LSB/g for ±16g range)
g_x = accel_x / 16384.0
g_y = accel_y / 16384.0
g_z = accel_z / 16384.0

# Get magnitude of acceleration (tilt/motion)
magnitude = Math.sqrt(g_x**2 + g_y**2 + g_z**2)
```

### Common Registers
| Addr | Purpose | Default | Notes |
|------|---------|---------|-------|
| 0x3B-0x40 | Accel X, Y, Z (6 bytes) | - | Read-only |
| 0x41-0x46 | Gyro X, Y, Z (6 bytes) | - | Read-only (optional) |
| 0x1C | Accel Config (FS_SEL) | 0x00 | ±16g range |
| 0x6B | Power Management 1 | 0x40 | Bit 6 = sleep (write 0x00 to wake) |

### Sampling Strategy
- **Typical rate**: 66Hz (15ms intervals)
- **Avoid**: Continuous rapid reads (slow I2C, creates CPU overhead)
- **Optimization**: Sample every N loop iterations, not every cycle

---

## Button Input (GPIO 39)

### Electrical Specification
- **GPIO**: 39 (input-only pin)
- **Type**: Capacitive touch pin, configured as digital GPIO
- **Logic**: Active LOW (pressed = 0, released = 1)
- **Internal Pull-Up**: Available (typically enabled in firmware)

### Reading Button State
```ruby
# Configure as input
GPIO.set_mode(39, :input)

# Read state
state = GPIO.read(39)
# state == 1 → Button released
# state == 0 → Button pressed
```

### Debouncing Strategy
```ruby
# Simple debounce (check multiple times)
def button_pressed?
  pressed_count = 0
  5.times do
    pressed_count += 1 if GPIO.read(39) == 0
    sleep(0.005)  # 5ms between reads
  end
  pressed_count >= 3  # Debounce: at least 3 of 5 reads are low
end
```

### Common Issues
| Problem | Cause | Solution |
|---------|-------|----------|
| Spurious presses | Electrical noise | Debounce in software (check 3-5 times) |
| Always pressed | GPIO not initialized | Call `GPIO.set_mode(39, :input)` |
| No response | Pin misconfiguration | Verify GPIO 39 in schematic |

---

## UART Communication (PC Interface)

### Specifications
- **UART**: UART0 (default serial)
- **Baud Rate**: 115200 bps (standard for ESP32)
- **Protocol**: 8N1 (8 data bits, no parity, 1 stop bit)
- **Connection**: USB → CP2102 → ESP32 RX0/TX0
- **PC Tool**: Serial monitor (minicom, screen, Arduino IDE, etc.)

### PicoRuby UART Usage
```ruby
# Initialize UART 0
uart = UART.new(0, 115200)

# Send string
uart.puts("Hello from ESP32!")

# Send raw bytes
uart.write([0x01, 0x02, 0x03])

# Read single byte
byte = uart.read(1)  # Returns array [byte_value]

# Read with timeout
data = uart.read_timeout(10, 100)  # Read 10 bytes, 100ms timeout
```

### Protocol Format (Drum System)
- **1 byte per message** (see finger-drum skill)
- **Format**: `0x01-0x3C` (MIDI notes/commands)
- **Example**: `0x24` = MIDI note 36 (kick drum)

---

## I2C Communication (Accelerometer)

### Specifications
- **SDA**: GPIO 25 (Serial Data)
- **SCL**: GPIO 21 (Serial Clock)
- **Speed**: 400kHz (standard I2C)
- **Voltage**: 3.3V (ESP32 standard)
- **Address**: 0x68 for MPU6886

### Wiring
```
GPIO 25 (SDA) ─── Pull-up resistor (4.7kΩ) ─── 3.3V
            └─── MPU6886 SDA pin

GPIO 21 (SCL) ─── Pull-up resistor (4.7kΩ) ─── 3.3V
            └─── MPU6886 SCL pin

GND ────────────── MPU6886 GND
3.3V ───────────── MPU6886 VCC
```

### Common Issues
| Problem | Cause | Solution |
|---------|-------|----------|
| I2C not responding | Missing pull-up resistors | Add 4.7kΩ resistors on SDA/SCL |
| Timeout errors | MPU6886 not powered | Check 3.3V supply |
| Wrong address | Different sensor variant | Verify address with I2C scanner |
| Data corruption | Loose connections | Resolder connectors, add 100nF decap |

---

## MIDI Output (Optional GPIO 23/33)

### Specifications
- **MIDI Standard**: DIN connector or 3.5mm jack
- **Baud Rate**: 31250 bps (MIDI standard)
- **TX Pin**: GPIO 23
- **RX Pin**: GPIO 33 (optional, for MIDI input)
- **Voltage**: 3.3V → 5V conversion may be needed

### MIDI Messages
```ruby
# Initialize MIDI UART
midi = UART.new(1, 31250)  # UART 1 for MIDI

# Note On (0x90 = Channel 1)
# [0x90, pitch, velocity]
midi.write([0x90, 36, 64])  # Kick drum (note 36), velocity 64

# Note Off (0x80)
# [0x80, pitch, 0]
midi.write([0x80, 36, 0])

# Control Change (0xB0)
# [0xB0, controller, value]
midi.write([0xB0, 7, 100])  # Volume control
```

### MIDI Note Numbers (for drums)
| Note | Decimal | Sound |
|------|---------|-------|
| C2 | 36 | Kick Drum |
| C#2 | 37 | Kick Drum (variant) |
| D2 | 38 | Snare Drum |
| E2 | 42 | Closed Hi-Hat |
| F#2 | 46 | Open Hi-Hat |
| G2 | 49 | Tom (Low) |

---

## Power Management

### Operating Conditions
- **Supply Voltage**: 3.3V (internal regulator, 5V input available)
- **Current Draw**:
  - Idle: ~100mA
  - Full load (WS2812 all white): ~3.6A external
  - Typical operation: 200-500mA

### Sleep Modes (Advanced)
- **Deep Sleep**: Minimal power, wakes on timer/button
- **Light Sleep**: Faster wake, moderate power savings
- **Current operation**: Always-on (no sleep management)

---

## Initialization Checklist

Before starting application:

- [ ] GPIO 22 initialized for WS2812 LED control
- [ ] I2C (GPIO 25/21) initialized for MPU6886
- [ ] GPIO 39 configured as input (button)
- [ ] UART0 initialized (115200 bps)
- [ ] MPU6886 woken up (write 0x00 to register 0x6B)
- [ ] LED strip powered (5V external)
- [ ] GND connections verified (critical for analog circuits)

---

## Hardware Schematic Resources

See actual implementation in:
- **PicoRuby App**: [src_components/R2P2-ESP32/storage/home/app.rb](src_components/R2P2-ESP32/storage/home/app.rb)
- **Hardware Config**: `build_config/xtensa-esp.rb`
- **Arduino Init Code**: `src_components/main/` (C++ initialization)

---

## Related Skills & Resources

- **picoruby-constraints**: Embedded coding best practices, memory optimization
- **finger-drum**: Full system example using all hardware components
- **led-visualization**: Advanced LED control techniques and color algorithms

---

## Version History

- v1.0 (2025-11-05): Initial documentation based on CLAUDE.md refactoring
