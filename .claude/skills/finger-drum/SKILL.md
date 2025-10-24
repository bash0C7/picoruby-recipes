# Finger Drum + FX Control System

## Overview

A real-time drum performance system combining DDJ-400 DJ controller with ATOM Matrix (ESP32) for expressive finger drumming with dynamic reverb and chorus control.

## When to Use This Skill

Mention this skill when:
- Working on **finger drum features** or performance optimization
- Implementing **DDJ-400 controller integration**
- Building **MIDI drum systems** with effect control
- Discussing **protocol v2** specifications
- Debugging **PC-to-ATOM communication** issues
- Exploring **drum kit selection** or sound design

Auto-triggered by keywords: `finger drum`, `DDJ-400`, `drum performance`, `MIDI drum`, `drum protocol`, `reverb control`, `chorus control`, `drum FX`

## System Architecture

See @architecture.md for detailed system design.

**Quick Summary**:
```
DDJ-400 → PC (CRuby) → UART → ATOM Matrix → MIDI Module
 Pads            MIDI          Protocol v2      Sound
 Knobs           Detection      (1-byte)
```

## Available Code Versions

### PC Side (CRuby)

1. **drum_midi.rb** - MIDI Controller Version
   - Listens to DDJ-400 via USB
   - Converts PAD presses and FILTER knob movements
   - Sends Protocol v2 commands via UART
   - Real-time display of all events
   - Best for: Live performance with DDJ-400

2. **drum_pc.rb** - Keyboard Version
   - Keyboard-controlled finger drum (no DDJ-400 needed)
   - z,x,c,v,b,n,m = basic drums
   - a-h = toms and percussion
   - 1-4 = special percussion
   - Polyphonic (simultaneous key presses)
   - Best for: Development, testing, practice without DDJ-400

### PicoRuby Side (ATOM Matrix)

1. **rwcc.rb** - Compact Drum Receiver
   - Ultra-minimal (200 lines)
   - Parse Protocol v2 commands
   - Send MIDI to sound module
   - Debug output
   - Memory efficient
   - Best for: Embedded deployment, limited RAM

2. **rwc.rb** - Full Version with LED Display
   - All features from rwcc.rb PLUS:
   - 60 LED WS2812 strip visualization
   - MPU6886 accelerometer integration
   - Acceleration → RGB color mapping
   - Acceleration → MIDI CC mapping
   - Perfect for live visual feedback
   - Best for: Stage performance, visual effects

## Protocol v2 Specification

See @protocol.md for complete protocol details.

**Quick Reference**:
```
36-56   : Drum Notes (21 sounds)
1-10    : Reverb Level (DECK1 FILTER)
11-20   : Chorus Level (DECK2 FILTER)

Baud: 115200 bps
All commands: 1 byte (ultra-simple!)
```

## Hardware Setup

```
ATOM Matrix (ESP32)
├── GPIO 22: WS2812 LED Strip (60 LEDs) - optional
├── GPIO 23/33: MIDI Unit (31250 bps)
├── GPIO 25/21: I2C (MPU6886) - optional
└── UART0: PC Connection (115200 bps)
```

## Key Design Philosophy

- **Simplicity**: 1-byte protocol = ultra-low latency (<5ms)
- **Expressiveness**: Two effect channels via FILTER knobs
- **Reliability**: No sync errors, no handshaking needed
- **Flexibility**: Multiple PC implementations (MIDI/Keyboard)

## Common Tasks

### Setup PC and ATOM
```bash
# PC side
cd src_components/pc
ruby drum_midi.rb     # or drum_pc.rb

# ATOM side - already running
```

### Change Drum Kit
In `rwcc.rb` or `rwc.rb`, line ~64:
```ruby
$md.write((0xC9).chr + (25).chr)  # Change 25 to desired kit
```

MIDI Drum Kit Numbers:
- 0: Standard
- 8: Room
- 16: Power
- 24: Electronic
- 25: **TR-808** (current default)
- 32: Jazz
- 40: Brush

### Add New Drum Sound
1. Add MIDI note (36-56 range) to `key_notes` or `deck*_to_drum` mapping
2. Instrument will automatically work with protocol v2
3. Both rwcc.rb and rwc.rb handle 36-56 range automatically

### Debug Issues

**Drums not playing?**
- Check MIDI Unit receives CC#91/93 (reverb/chorus)
- Verify baud rate: 115200 (PC) ↔ UART0, 31250 (MIDI Module) ↔ UART1
- Confirm DR-808 kit supports the note range

**LED not lighting?**
- Only in rwc.rb (full version)
- Check WS2812 connected to GPIO 22
- Verify LED count = 60 in initialization

**Knobs not responding?**
- DDJ-400 sends CC#23 (DECK1 FILTER) and CC#24 (DECK2 FILTER)
- Verify with MIDI monitoring tool
- Check PC side correctly maps MSB to 0-9 levels

## Related Documentation

- @drum_readme.rb - Full user guide (Japanese)
- @drum_protcolspec.md - Complete protocol specification
- @drum_midi.rb - PC MIDI version source code
- @drum_pc.rb - PC keyboard version source code
- @rwcc.rb - PicoRuby compact receiver source
- @rwc.rb - PicoRuby full receiver with LED source
