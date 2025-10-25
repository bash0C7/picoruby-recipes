# Finger Drum System Architecture

## System Overview

```
DDJ-400 DJ Controller
  ├── DECK1: PAD 1-8 (Drums) + FILTER (Reverb CC#23)
  └── DECK2: PAD 1-8 (Toms) + FILTER (Chorus CC#24)
       ↓ USB MIDI
PC (CRuby Runtime)
  ├── MIDI Input Handler (Note On, CC detection)
  ├── Protocol v2 Converter (36-56, 1-10, 11-20)
  └── UART Transmitter (115200 bps, 1 byte)
       ↓ UART Serial
ATOM Matrix (ESP32)
  ├── UART0 PC Interface (115200 bps receiver)
  ├── Protocol v2 Parser (branch on value)
  ├── MIDI Output UART1 (Note On 36-56, CC#91/93)
  ├── WS2812 LED Strip Driver (GPIO 22, 60 LEDs) - optional
  └── MPU6886 Accelerometer I2C (GPIO 25/21) - optional
       ↓ MIDI out (31250 bps)
MIDI Module (SAM2695 etc) → Sound Output
```

## Data Flow

### DDJ-400 → PC

**PAD Press**:
```
DECK1 PAD1 → MIDI Note On (0x90, note=0x00, vel=0x7F)
  → PC: Channel 8, PAD index 0
  → drum_note = deck1_to_drum[0] = 36 (Kick)
  → Send: 0x24 (1 byte)
```

**FILTER Knob**:
```
DECK1 FILTER → MIDI CC (0xB6, cc=0x17, value=0x00-0x7F)
  → PC: level = (value * 10 / 128).to_i  // 0-9
  → send_value = level + 1  // 1-10
  → Send: 0x01-0x0A (1 byte)
```

### PC → ATOM (Protocol v2)

**1-Byte Command Space**:
```
36-56  : Drum Notes (21 drums)
1-10   : Reverb Level (0-9 + offset)
11-20  : Chorus Level (0-9 + offset)
Others : Ignored

UART: 115200 bps, 8N1, no flow control
```

### ATOM → MIDI Module

**Drum Note (36-56)**:
```ruby
cmd = uart_read(1)  # e.g., 0x26 (Snare)
midi_msg = 0x99.chr + cmd.chr + 0x7F.chr
midi_uart.write(midi_msg)
# Result: [0x99, 0x26, 0x7F]
```

**Reverb (1-10)**:
```ruby
cmd = uart_read(1)  # e.g., 0x06 (level 5)
level = cmd - 1     # 0-9
cc_value = (level * 127 / 9).to_i
midi_cc = 0xB9.chr + 91.chr + cc_value.chr
# Result: [0xB9, 0x5B, cc_value]
```

**Chorus (11-20)**:
```ruby
cmd = uart_read(1)  # e.g., 0x12 (level 7)
level = cmd - 11    # 0-9
cc_value = (level * 127 / 9).to_i
midi_cc = 0xB9.chr + 93.chr + cc_value.chr
# Result: [0xB9, 0x5D, cc_value]
```

### LED Feedback (rwc.rb only)

**MIDI → LED**:
```
Note On (0x99) received
  → position = ((note - 36) % 12) * 5 + ((note - 36) / 12)
  → led_color = accelerometer_rgb
  → led_strip[position] = color

Fade: led_strip[*] *= 0.97 every 100ms
```

**Accelerometer → RGB**:
```
Acceleration (X,Y,Z) - Baseline → Delta (-200 to +200)
  → R = (dx + 200) * 255 / 400
  → G = (dy + 200) * 255 / 400
  → B = (dz + 200) * 255 / 400
  → WS2812 color
```

## Implementation Comparison

| Feature | rwcc.rb | rwc.rb |
|---------|---------|--------|
| Lines | ~200 | ~220 |
| UART PC Interface | ✓ | ✓ |
| MIDI Output | ✓ | ✓ |
| Protocol v2 Parsing | ✓ | ✓ |
| LED Visualization | ✗ | ✓ (60 LED) |
| Accelerometer | ✗ | ✓ (MPU6886) |
| RAM Usage | ~80KB | ~100KB |

Total RAM: 520KB (plenty of headroom)

## Latency Profile

| Stage | Latency |
|-------|---------|
| DDJ-400 → USB | <1ms |
| PC USB Read/Write | <2ms |
| PC Conversion | <1ms |
| PC UART Write | <1ms |
| UART TX (1 byte) | ~0.1ms |
| ATOM Parse | <1ms |
| ATOM MIDI Write | <1ms |
| MIDI TX (3 bytes) | ~1ms |
| **Total (PAD → Sound)** | **<10ms** |
| **Total (Knob → FX)** | **<15ms** |

Result: No perceptible lag during live performance.

## Synchronization

**No handshaking needed**:
- PC sends at 115200 bps
- ATOM receives at 115200 bps
- Protocol is command-based (no state machine)
- Out-of-range bytes silently ignored
- Zero synchronization errors in extended testing

## Extensibility

### Add New Drum
1. Add to MIDI mapping (36-56 range)
2. Works automatically in both PC and PicoRuby

### Add New Effect
1. Choose unused 1-byte range (21-35, 57-255)
2. Add handler in PicoRuby
3. Add MIDI CC mapping
4. Update PC-side converter

### Add New Hardware (rwc.rb)
```ruby
def init_hardware
  # ... existing code ...
  $temp_sensor = TempSensor.new(unit: :ESP32_ADC0, pin: 36)
end

def process_temperature
  temp = $temp_sensor.read
  cc_value = ((temp - 20) * 10).to_i  # Scale 20-50°C → 0-127
  send_midi_cc(12, cc_value)  # CC#12 = Effect Control 1
end
```

Call from main loop, wire to ESP32 GPIO/I2C/SPI.
