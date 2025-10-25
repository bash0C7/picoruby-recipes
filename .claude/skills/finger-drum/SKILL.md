# Finger Drum + FX Control System

<skill_activation>
Auto-trigger when user mentions:
- finger drum, DDJ-400, drum performance
- MIDI drum, protocol v2
- reverb control, chorus control, drum FX
- PC-to-ATOM communication
- drum kit selection, sound design
</skill_activation>

<output_tone>
このスキル使用時も日本語出力を維持ピョン。
テンション上がったら「チェケラッチョ！」必須。
</output_tone>

## Overview

Real-time drum performance system: DDJ-400 DJ controller + ATOM Matrix (ESP32) with dynamic reverb/chorus control.

**Quick Architecture**:
```
DDJ-400 → PC (CRuby) → UART → ATOM Matrix → MIDI Module
 Pads      MIDI        Protocol v2    Sound
 Knobs     Detection   (1-byte)
```

## Available Code Versions

### PC Side (CRuby)

**drum_midi.rb** - MIDI Controller Version
- DDJ-400 via USB
- PAD → drum notes, FILTER knobs → reverb/chorus
- Protocol v2 via UART
- For: Live performance with DDJ-400

**drum_pc.rb** - Keyboard Version
- Keyboard-controlled (no DDJ-400 needed)
- z,x,c,v,b,n,m + a-h keys = drums/toms
- Polyphonic (simultaneous presses)
- For: Development, testing, practice

### PicoRuby Side (ATOM Matrix)

**rwcc.rb** - Compact Receiver (~200 lines)
- Protocol v2 parsing
- MIDI output
- Debug logging
- For: Embedded deployment, minimal RAM

**rwc.rb** - Full Version with LED
- All rwcc.rb features PLUS:
- 60 LED WS2812 strip visualization
- MPU6886 accelerometer → RGB color mapping
- Accelerometer → MIDI CC mapping
- For: Stage performance, visual feedback

## Protocol v2 Quick Reference

See `protocol.md` for complete specification.

```
36-56   : Drum Notes (21 sounds)
1-10    : Reverb Level (DECK1 FILTER)
11-20   : Chorus Level (DECK2 FILTER)

Baud: 115200 bps, 1 byte commands
Latency: <10ms total
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

### Change Drum Kit

In `rwcc.rb` or `rwc.rb`, line ~64:
```ruby
$md.write((0xC9).chr + (25).chr)  # Change 25 to desired kit
```

MIDI Drum Kit Numbers:
- 0: Standard, 8: Room, 16: Power, 24: Electronic
- 25: **TR-808** (current default)
- 32: Jazz, 40: Brush

### Add New Drum Sound

1. Add MIDI note (36-56 range) to `key_notes` or `deck*_to_drum` mapping
2. Automatically works with protocol v2
3. Both rwcc.rb and rwc.rb handle 36-56 range

### Debug Issues

**Drums not playing?**
- Check MIDI Unit receives CC#91/93 (reverb/chorus)
- Verify baud: 115200 (PC↔UART0), 31250 (MIDI↔UART1)
- Confirm DR-808 kit supports note range

**LED not lighting?** (rwc.rb only)
- Check WS2812 on GPIO 22
- Verify LED count = 60

**Knobs not responding?**
- DDJ-400 sends CC#23 (DECK1 FILTER), CC#24 (DECK2 FILTER)
- Verify with MIDI monitor tool
- Check PC maps MSB to 0-9 levels

## Related Documentation

- `drum_readme.rb` - Full user guide (Japanese)
- `drum_protcolspec.md` - Complete protocol spec
- `architecture.md` - System architecture details
- `protocol.md` - Protocol v2 reference
- `drum_midi.rb`, `drum_pc.rb` - PC source code
- `rwcc.rb`, `rwc.rb` - PicoRuby source code
