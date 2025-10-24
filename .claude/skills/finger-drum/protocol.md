# Protocol v2 Reference Guide

## Quick Reference Table

```
┌─────────────────────────────────────────────────────────────┐
│           Protocol v2 Command Space (1 byte)                │
├─────────┬──────────────────────────────────────────────────┤
│ 0-35    │ Reserved (silently ignored)                      │
│ 36-56   │ Drum Notes (21 different percussion sounds)      │
│ 57-255  │ Reserved (silently ignored)                      │
│ 1-10    │ Reverb Level (0-9 effective, +1 offset)          │
│ 11-20   │ Chorus Level (0-9 effective, +11 offset)         │
└─────────┴──────────────────────────────────────────────────┘
```

## Drum Notes (36-56)

Complete MIDI General Percussion mapping following standard MIDI drum protocol (Channel 10).

| Dec | Hex  | Instrument | Notes |
|-----|------|------------|-------|
| 36  | 0x24 | Kick (Bass Drum) | Deep, fundamental drum sound |
| 37  | 0x25 | *Reserved* | (not used in protocol) |
| 38  | 0x26 | Snare | Bright, attack-rich drum |
| 39  | 0x27 | Hand Clap | Percussive, organic |
| 40  | 0x28 | *Reserved* | (not used in protocol) |
| 41  | 0x29 | Low Tom | Lowest pitched tom |
| 42  | 0x2A | Closed Hi-Hat | Tight, controlled sound |
| 43  | 0x2B | Low-Mid Tom | Lower-mid register |
| 44  | 0x2C | Pedal Hi-Hat | *Reserved* (not used) |
| 45  | 0x2D | Mid Tom | Center frequency |
| 46  | 0x2E | Open Hi-Hat | Shimmery, sustained sound |
| 47  | 0x2F | Mid-Hi Tom | Higher-mid register |
| 48  | 0x30 | Hi Tom | Highest pitched tom |
| 49  | 0x31 | Crash Cymbal | Bright, explosive crash |
| 50  | 0x32 | High Tom | Very high pitched tom |
| 51  | 0x33 | Ride Cymbal | Sustained, bell-like |
| 52  | 0x34 | Chinese Cymbal | Dark, exotic crash |
| 53  | 0x35 | *Reserved* | (not used in protocol) |
| 54  | 0x36 | Tambourine | Jingle, rattle sound |
| 55  | 0x37 | *Reserved* | (not used in protocol) |
| 56  | 0x38 | Cowbell | Metallic, pitch-capable |

### Drum Mapping in Hardware

**DECK1 (Left Side) - Basic Kit**:
```
PAD1 (index 0) → 36 (Kick)
PAD2 (index 1) → 38 (Snare)
PAD3 (index 2) → 42 (Closed Hi-Hat)
PAD4 (index 3) → 46 (Open Hi-Hat)
PAD5 (index 4) → 49 (Crash Cymbal)
PAD6 (index 5) → 51 (Ride Cymbal)
PAD7 (index 6) → 39 (Hand Clap)
PAD8 (index 7) → 56 (Cowbell)
```

**DECK2 (Right Side) - Toms & Percussion**:
```
PAD1 (index 0) → 41 (Low Tom)
PAD2 (index 1) → 43 (Low-Mid Tom)
PAD3 (index 2) → 45 (Mid Tom)
PAD4 (index 3) → 47 (Mid-Hi Tom)
PAD5 (index 4) → 48 (Hi Tom)
PAD6 (index 5) → 50 (High Tom)
PAD7 (index 6) → 54 (Tambourine)
PAD8 (index 7) → 52 (Chinese Cymbal)
```

## Reverb Control (1-10)

Sent via DECK1 FILTER knob (CC#23 from DDJ-400)

| Command | Dec | Hex  | Effect | CC Value | Use Case |
|---------|-----|------|--------|----------|----------|
| Level 0 | 1   | 0x01 | Dry (no reverb) | 0 | Tight, punchy drums |
| Level 1 | 2   | 0x02 | Minimal reverb | 14 | Light space |
| Level 2 | 3   | 0x03 | Light reverb | 28 | Subtle ambience |
| Level 3 | 4   | 0x04 | Low-medium reverb | 43 | Medium reverb |
| Level 4 | 5   | 0x05 | Medium reverb | 57 | Balanced |
| Level 5 | 6   | 0x06 | Medium-high reverb | 71 | Rich space |
| Level 6 | 7   | 0x07 | High reverb | 85 | Spacious sound |
| Level 7 | 8   | 0x08 | Very high reverb | 99 | Dramatic effect |
| Level 8 | 9   | 0x09 | Extreme reverb | 113 | Washy, experimental |
| Level 9 | 10  | 0x0A | Maximum reverb (wet) | 127 | Full reverb |

### PC-side Calculation

```ruby
# From DDJ-400 DECK1 FILTER (CC#23, range 0-127)
cc_value = midi_bytes[2]  # 0-127

# Convert to 10 levels (0-9)
level = (cc_value * 10 / 128).to_i  # 0-9
level = 9 if level > 9              # Clamp

# Offset to 1-10 for protocol
send_value = level + 1              # 1-10

# Send as 1 byte
serial.write(send_value.chr)
```

### PicoRuby-side Processing

```ruby
# From UART (received as 1-10)
cmd = uart_read(1)[0].ord  # 1-10

# Convert back to 0-9
level = cmd - 1            # 0-9

# Map to MIDI CC value (0-127)
cc_value = (level * 127 / 9).to_i  # 0-127
cc_value = 127 if cc_value > 127   # Clamp

# Send MIDI CC#91 (Reverb Send Level)
midi_cc = 0xB9.chr + 91.chr + cc_value.chr
midi_uart.write(midi_cc)
```

### MIDI Standard

- **CC#91**: Reverb Send Level (standard MIDI effect control)
- **Channel**: 10 (0x09, General MIDI Drums)
- **Value Range**: 0-127

## Chorus Control (11-20)

Sent via DECK2 FILTER knob (CC#24 from DDJ-400)

| Command | Dec | Hex  | Effect | CC Value | Use Case |
|---------|-----|------|--------|----------|----------|
| Level 0 | 11  | 0x0B | Dry (no chorus) | 0 | Tight, focused sound |
| Level 1 | 12  | 0x0C | Minimal chorus | 14 | Subtle width |
| Level 2 | 13  | 0x0D | Light chorus | 28 | Slight thickening |
| Level 3 | 14  | 0x0E | Low-medium chorus | 43 | Moderate width |
| Level 4 | 15  | 0x0F | Medium chorus | 57 | Balanced thickness |
| Level 5 | 16  | 0x10 | Medium-high chorus | 71 | Rich, layered |
| Level 6 | 17  | 0x11 | High chorus | 85 | Very wide sound |
| Level 7 | 18  | 0x12 | Very high chorus | 99 | Thick, lush |
| Level 8 | 19  | 0x13 | Extreme chorus | 113 | Heavily processed |
| Level 9 | 20  | 0x14 | Maximum chorus (thick, wide) | 127 | Full effect |

### PC-side Calculation

```ruby
# From DDJ-400 DECK2 FILTER (CC#24, range 0-127)
cc_value = midi_bytes[2]  # 0-127

# Convert to 10 levels (0-9)
level = (cc_value * 10 / 128).to_i  # 0-9
level = 9 if level > 9              # Clamp

# Offset to 11-20 for protocol
send_value = level + 11             # 11-20

# Send as 1 byte
serial.write(send_value.chr)
```

### PicoRuby-side Processing

```ruby
# From UART (received as 11-20)
cmd = uart_read(1)[0].ord  # 11-20

# Convert back to 0-9
level = cmd - 11           # 0-9

# Map to MIDI CC value (0-127)
cc_value = (level * 127 / 9).to_i  # 0-127
cc_value = 127 if cc_value > 127   # Clamp

# Send MIDI CC#93 (Chorus Send Level)
midi_cc = 0xB9.chr + 93.chr + cc_value.chr
midi_uart.write(midi_cc)
```

### MIDI Standard

- **CC#93**: Chorus Send Level (standard MIDI effect control)
- **Channel**: 10 (0x09, General MIDI Drums)
- **Value Range**: 0-127

## Communication Parameters

| Parameter | Value |
|-----------|-------|
| Baud Rate | 115200 bps |
| Data Bits | 8 |
| Parity | None |
| Stop Bits | 1 |
| Flow Control | None |

## Timing & Performance

### Latency Budget

| Stage | Latency |
|-------|---------|
| DDJ-400 → USB | <1ms |
| PC USB Read | <2ms |
| PC Calculation | <1ms |
| PC UART Write | <1ms |
| UART Transmission | 0.1ms (1 byte @ 115200) |
| ATOM Parse | <1ms |
| ATOM MIDI Write | <1ms |
| MIDI Transmission | 1ms (3 bytes @ 31250) |
| **Total** | **<10ms** |

### Bandwidth

- **Typical**: 50-100 bytes/sec (occasional PAD hits + slow knob turns)
- **Peak**: 500 bytes/sec (rapid drumming + fast knob adjustments)
- **Capacity**: 115200 bps = 11,520 bytes/sec
- **Utilization**: <5% even at peak

## State Management

### Value Change Detection

To prevent redundant UART traffic, PC-side code only sends FX changes when value actually changes:

```ruby
# Global state
current_reverb_level = 5
current_chorus_level = 5

# In event loop:
if level != current_reverb_level
  current_reverb_level = level
  send_value = level + 1
  serial.write(send_value.chr)
  puts "Reverb changed to #{level}"
end
```

This ensures smooth knob operation without flooding UART with redundant commands.

## Error Handling

### Out-of-Range Bytes

Bytes outside valid ranges are **silently ignored**:
- < 1 or > 56 (excluding 11-20 range)
- No error reporting needed
- No state corruption possible

### Recovery

Protocol is stateless — no special recovery needed. If corrupted byte received, next valid byte resets context.

## Implementation Checklist

- [ ] PC UART: 115200 bps, 8N1
- [ ] ATOM UART0: 115200 bps, 8N1 (receive)
- [ ] ATOM UART1: 31250 bps (MIDI out)
- [ ] Drum notes: Send bare value (36-56)
- [ ] Reverb: Send level+1 (1-10 range)
- [ ] Chorus: Send level+11 (11-20 range)
- [ ] MIDI Channel: 10 (0x09) for drums
- [ ] Note On velocity: 0x7F (127)
- [ ] CC#91: Reverb (mapped from 0-9 → 0-127)
- [ ] CC#93: Chorus (mapped from 0-9 → 0-127)
- [ ] Clamp all MIDI values to 0-127

## Version History

### v1 (Original)
- Drum notes only (36-56)
- No effect control
- Ultra-simple

### v2 (Current)
- **NEW**: Reverb level control (1-10)
- **NEW**: Chorus level control (11-20)
- Maintains 1-byte simplicity
- Added DDJ-400 FILTER knob integration
- Zero added complexity to protocol

## Design Rationale

### Why 1 Byte?

- Ultra-low latency (<5ms for drums)
- No buffering, no framing needed
- No synchronization errors
- Perfect for real-time performance

### Why These Ranges?

```
1-10   : Low, easy to reach
11-20  : Adjacent to reverb
36-56  : MIDI drum standard (widely supported)
```

All ranges non-overlapping, no ambiguity.

### Why CC#91 and CC#93?

These are the **standard MIDI effect controls**:
- **CC#91**: Reverb Send Level (reverb effect output level)
- **CC#93**: Chorus Send Level (chorus effect output level)
- Maximum compatibility with synthesizers and sound modules
- Automatically recognized by GM2-compliant devices

### Why 10 Levels?

- Sufficient resolution for expressive control
- Maps naturally to 0-9 internal representation
- Fits perfectly in 1-byte protocol
- Easy mental model for performers
