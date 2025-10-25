# Protocol v2 Reference Guide

## Command Space (1 byte)

```
┌─────────┬──────────────────────────────────────────┐
│ Range   │ Interpretation                           │
├─────────┼──────────────────────────────────────────┤
│ 0-35    │ Reserved (ignored)                       │
│ 36-56   │ Drum Notes (21 percussion sounds)        │
│ 57-255  │ Reserved (ignored)                       │
│ 1-10    │ Reverb Level (0-9 effective, +1 offset)  │
│ 11-20   │ Chorus Level (0-9 effective, +11 offset) │
└─────────┴──────────────────────────────────────────┘
```

## Drum Notes (36-56)

General MIDI Percussion (Channel 10)

| Dec | Hex  | Instrument | Dec | Hex  | Instrument |
|-----|------|------------|-----|------|------------|
| 36  | 0x24 | Kick       | 47  | 0x2F | Mid-Hi Tom |
| 38  | 0x26 | Snare      | 48  | 0x30 | Hi Tom |
| 39  | 0x27 | Hand Clap  | 49  | 0x31 | Crash Cymbal |
| 41  | 0x29 | Low Tom    | 50  | 0x32 | High Tom |
| 42  | 0x2A | Closed HH  | 51  | 0x33 | Ride Cymbal |
| 43  | 0x2B | Low-Mid Tom| 52  | 0x34 | Chinese Cymbal |
| 45  | 0x2D | Mid Tom    | 54  | 0x36 | Tambourine |
| 46  | 0x2E | Open HH    | 56  | 0x38 | Cowbell |

### Hardware Mapping

**DECK1 (Left) - Basic Kit**:
```
PAD1→36(Kick), PAD2→38(Snare), PAD3→42(Closed HH), PAD4→46(Open HH)
PAD5→49(Crash), PAD6→51(Ride), PAD7→39(Clap), PAD8→56(Cowbell)
```

**DECK2 (Right) - Toms & Percussion**:
```
PAD1→41(Low Tom), PAD2→43(Low-Mid), PAD3→45(Mid), PAD4→47(Mid-Hi)
PAD5→48(Hi Tom), PAD6→50(High Tom), PAD7→54(Tambourine), PAD8→52(Chinese)
```

## Reverb Control (1-10)

From DECK1 FILTER knob (CC#23)

| Cmd | Dec | Hex  | Effect | CC Val | Use Case |
|-----|-----|------|--------|--------|----------|
| 0   | 1   | 0x01 | Dry    | 0      | Tight, punchy |
| 1   | 2   | 0x02 | Minimal| 14     | Light space |
| 2   | 3   | 0x03 | Light  | 28     | Subtle |
| 3   | 4   | 0x04 | Low-med| 43     | Medium |
| 4   | 5   | 0x05 | Medium | 57     | Balanced |
| 5   | 6   | 0x06 | Med-hi | 71     | Rich space |
| 6   | 7   | 0x07 | High   | 85     | Spacious |
| 7   | 8   | 0x08 | V.high | 99     | Dramatic |
| 8   | 9   | 0x09 | Extreme| 113    | Experimental |
| 9   | 10  | 0x0A | Max    | 127    | Full reverb |

**MIDI**: CC#91 (Reverb Send Level), Channel 10

### PC-side Calculation
```ruby
cc_value = midi_bytes[2]  # 0-127 from DDJ-400
level = (cc_value * 10 / 128).to_i  # 0-9
send_value = level + 1  # 1-10
serial.write(send_value.chr)
```

### PicoRuby-side Processing
```ruby
cmd = uart_read(1)[0].ord  # 1-10
level = cmd - 1  # 0-9
cc_value = (level * 127 / 9).to_i  # 0-127
midi_cc = 0xB9.chr + 91.chr + cc_value.chr
midi_uart.write(midi_cc)
```

## Chorus Control (11-20)

From DECK2 FILTER knob (CC#24)

| Cmd | Dec | Hex  | Effect | CC Val | Use Case |
|-----|-----|------|--------|--------|----------|
| 0   | 11  | 0x0B | Dry    | 0      | Tight, focused |
| 1   | 12  | 0x0C | Minimal| 14     | Subtle width |
| 2   | 13  | 0x0D | Light  | 28     | Slight thick |
| 3   | 14  | 0x0E | Low-med| 43     | Moderate |
| 4   | 15  | 0x0F | Medium | 57     | Balanced |
| 5   | 16  | 0x10 | Med-hi | 71     | Rich, layered |
| 6   | 17  | 0x11 | High   | 85     | Very wide |
| 7   | 18  | 0x12 | V.high | 99     | Thick, lush |
| 8   | 19  | 0x13 | Extreme| 113    | Heavily proc |
| 9   | 20  | 0x14 | Max    | 127    | Full effect |

**MIDI**: CC#93 (Chorus Send Level), Channel 10

### PC-side Calculation
```ruby
cc_value = midi_bytes[2]  # 0-127 from DDJ-400
level = (cc_value * 10 / 128).to_i  # 0-9
send_value = level + 11  # 11-20
serial.write(send_value.chr)
```

### PicoRuby-side Processing
```ruby
cmd = uart_read(1)[0].ord  # 11-20
level = cmd - 11  # 0-9
cc_value = (level * 127 / 9).to_i  # 0-127
midi_cc = 0xB9.chr + 93.chr + cc_value.chr
midi_uart.write(midi_cc)
```

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
| UART TX (1 byte) | 0.1ms |
| ATOM Parse | <1ms |
| ATOM MIDI Write | <1ms |
| MIDI TX (3 bytes) | 1ms |
| **Total** | **<10ms** |

### Bandwidth

- Typical: 50-100 bytes/sec (occasional PAD + slow knob)
- Peak: 500 bytes/sec (rapid drumming + fast knobs)
- Capacity: 115200 bps = 11,520 bytes/sec
- Utilization: <5% even at peak

## State Management

**Value Change Detection** (PC-side):
```ruby
current_reverb_level = 5
current_chorus_level = 5

if level != current_reverb_level
  current_reverb_level = level
  send_value = level + 1
  serial.write(send_value.chr)
end
```

Prevents redundant UART traffic for smooth knob operation.

## Error Handling

**Out-of-Range Bytes**: Silently ignored (< 1 or > 56 excluding 11-20)
**Recovery**: Protocol is stateless—no special recovery needed

## Implementation Checklist

- [ ] PC UART: 115200 bps, 8N1
- [ ] ATOM UART0: 115200 bps, 8N1 (receive)
- [ ] ATOM UART1: 31250 bps (MIDI out)
- [ ] Drum notes: Send bare value (36-56)
- [ ] Reverb: Send level+1 (1-10 range)
- [ ] Chorus: Send level+11 (11-20 range)
- [ ] MIDI Channel: 10 (0x09) for drums
- [ ] Note On velocity: 0x7F (127)
- [ ] CC#91: Reverb (0-9 → 0-127)
- [ ] CC#93: Chorus (0-9 → 0-127)
- [ ] Clamp all MIDI values to 0-127

## Version History

**v1**: Drum notes only (36-56), ultra-simple
**v2** (Current): Added reverb (1-10) + chorus (11-20), maintains 1-byte simplicity

## Design Rationale

### Why 1 Byte?
- Ultra-low latency (<5ms)
- No buffering/framing needed
- No synchronization errors
- Perfect for real-time performance

### Why These Ranges?
```
1-10   : Low, easy to reach
11-20  : Adjacent to reverb
36-56  : MIDI drum standard (widely supported)
```
Non-overlapping, no ambiguity.

### Why CC#91 and CC#93?
- Standard MIDI effect controls
- Maximum compatibility with synthesizers
- Automatically recognized by GM2-compliant devices

### Why 10 Levels?
- Sufficient resolution for expressive control
- Natural 0-9 internal representation
- Fits perfectly in 1-byte protocol
- Easy mental model for performers
