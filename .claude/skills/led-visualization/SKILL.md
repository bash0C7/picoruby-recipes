---
name: led-visualization
description: Design, tune, and debug WS2812 LED visualization for finger drum performances. Dual-point dynamic flashing with acceleration-driven color gradients. Use when working with LED effects, brightness/color tuning, fade timing, pseudo-random distribution, or debugging light synchronization issues in rwc.rb.
---

# LED Visualization System

Real-time WS2812 LED control for dynamic finger drum performances with intelligent dual-point flashing and acceleration sensor color mapping.

## When to Use This Skill

Mention LED visualization when:
- **Tuning brightness, color, or fade timing** in LED effects
- **Debugging LED synchronization** or timing issues
- **Optimizing memory or CPU** for LED processing
- **Implementing new visual effects** or patterns
- **Working with rwc.rb** LED implementation
- **Adjusting pseudo-random LED distribution** patterns
- **Integrating accelerometer color control**

Auto-triggered by keywords: `LED`, `WS2812`, `点灯`, `flash`, `fade`, `brightness`, `saturation`, `color`, `加速度`, `MPU6886`, `tilt`, `LED演出`, `ビジュアライザー`, `rwc.rb`

## System Overview

```
Drum PAD Hit
    ↓
Protocol v2 (1-byte command)
    ↓
ATOM Matrix
    ├─ UART0: Receive from PC (115200bps)
    ├─ LED Strip: GPIO 22 (60x WS2812)
    ├─ Accel Sensor: I2C GPIO 21/25 (MPU6886)
    └─ MIDI Out: GPIO 23/33 (31250bps)
    ↓
LED Flash Processing
    ├─ 2-point simultaneous lighting
    ├─ 7-position spread (±3 around center)
    ├─ Saturation-based color fade to white
    └─ Acceleration-driven color gradient
    ↓
Visual Result
    └─ Dual dynamic flashes with sustained glow
```

## Key Parameters (Quick Reference)

| Parameter | Value | Purpose | Tuning Range |
|-----------|-------|---------|--------------|
| **Velocity Scaling** | `vel * 2` | Center brightness | `vel`, `vel * 1.5`, `vel * 3` |
| **Spread Range** | ±3 LEDs | Glow radius | ±1, ±3, ±5 |
| **Saturation Levels** | 255/179/102/51 | Color fade rate | Custom array |
| **Fade Interval** | 15 loops | Decay frequency (~15ms) | 8, 15, 30, 100 |
| **Fade Rate** | 3% per step | Brightness decay | 2%, 3%, 5% |
| **Pseudo-random** | `$lc * 7 + note * 3` | Distribution seed | Coprime: 7, 11, 13 |
| **Collision Avoid** | ±5 distance | Min spacing | 5, 10 LEDs |
| **Accel Clamp** | ±200 | Color response range | ±150, ±200, ±300 |

## Quick Start: Common Tweaks

### Make LEDs Brighter
```ruby
# In light_flash(), change:
bri = (vel * 3).clamp(0, 255)  # Was: vel * 2
```

### Make Fade Longer
```ruby
# In main loop, change fade interval:
if $lc % 25 == 0  # Was: % 15 (25ms vs 15ms)
  # ... fade code ...
end
```

### More Random Distribution
```ruby
# In flash_drum(), change:
pos2 = ($lc * 11 + note * 3) % 60  # Was: 7 (11 for different pattern)
```

### Tighter LED Spread
```ruby
# In light_flash(), reduce array:
[
  [pos, 255, bri],
  [pos-1, 179, bri], [pos+1, 179, bri]
  # Remove ±2, ±3 entries
]
```

## Implementation Files

- **rwc.rb**: Full implementation with LED, accel, MIDI
- **drum_led.md**: Complete technical documentation
- **tuning.md**: Detailed parameter adjustment guide
- **visual-patterns.md**: Effect pattern gallery
- **troubleshooting.md**: Common issues and solutions

See @tuning.md for comprehensive adjustment guide.
See @visual-patterns.md for effect timing examples.
See @troubleshooting.md for debugging LED issues.

## Core Algorithm (30-second version)

### Per Drum Hit
```ruby
# 1. Get 2 positions
pos1 = DRUM_LED[note]          # PAD-mapped (0-15 typical)
pos2 = ($lc * 7 + note*3) % 60 # Pseudo-random (spread across 16-59)

# 2. Get current color (accel-driven)
color = get_color()  # X/Y/Z tilt → R/G/B

# 3. Light both positions
[pos1, pos2].each do |pos|
  # Center: full saturation (255)
  # ±1: 70% saturation (179)
  # ±2: 40% saturation (102)
  # ±3: 20% saturation (51)
  # Each LED gets: saturated_color * (brightness/255) | existing
end
```

### Every 15 Loop Iterations (≈15ms)
```ruby
if $lc % 15 == 0
  60.times do |i|
    $co[i] = $co[i] * 97 / 100  # Fade by 3%
    $co[i] = 0 if $co[i] <= 5   # Kill very dim
  end
end
```

## Integration Points

### With Finger Drum System
- Receives Protocol v2 commands (36-56 for drums)
- Synced with MIDI output (both triggered together)
- Shares ATOM Matrix hardware (GPIO, I2C, UART)

### With PC Communication
- rwc.rb listens on UART0 (115200bps)
- LED updates independent, no PC blocking
- Color changes based on local acceleration

## Performance Profile

| Metric | Value | Status |
|--------|-------|--------|
| Memory Usage | <100KB | ✓ Safe |
| CPU Utilization | <10% | ✓ Abundant headroom |
| PAD→LED Latency | <10ms | ✓ Imperceptible |
| Loop Time | ~1ms | ✓ 1000 iterations/sec |
| FPS (visual) | 60 FPS equiv | ✓ Smooth |

## Customization Levels

### Beginner (Brightness Only)
- Adjust `vel * 2` to `vel * 1.5` or `vel * 3`
- Tweak fade rate: 2%, 3%, 5%
- Done! See @tuning.md section "Brightness Adjustment"

### Intermediate (Color & Timing)
- Adjust saturation array: [255, 179, 102, 51] → custom
- Change fade interval: 8, 15, 30, 100 loops
- Modify spread range: ±1, ±3, ±5
- See @tuning.md section "Saturation Tuning"

### Advanced (Distribution & Optimization)
- Change pseudo-random multiplier: 7→11→13
- Customize collision avoidance logic
- Profile and optimize CPU/memory
- See @tuning.md section "Performance Optimization Tips"

## Debugging Checklist

✓ LEDs not lighting?
- Check GPIO 22 connection
- Verify RMTDriver initialization
- Confirm 5V power to strip

✓ Colors not changing with tilt?
- Verify I2C setup (GPIO 21/25)
- Check MPU6886 initialization
- Run accel calibration 5-point average

✓ Same positions always light?
- Increase pseudo-random coefficient (7→11)
- Verify collision avoidance logic

✓ Too much/little glow?
- Adjust fade interval (8→100 loops)
- Change fade rate (2%→5% decay)
- Reduce/increase velocity scaling

See @troubleshooting.md for detailed solutions.

## Related Skills & Documentation

- **finger-drum**: Parent skill for drum protocol and MIDI
- **drum_led.md**: Full technical reference (visual timelines, equations)
- **rwc.rb**: Source implementation (~207 lines)

## What's Possible

- ✓ Full 60-LED utilization (no dead zones)
- ✓ Polyphonic visual effects (OR accumulation)
- ✓ Real-time color feedback (accel-driven)
- ✓ Adjustable glow duration (1-5 seconds)
- ✓ CPU-efficient processing (<1ms/loop)
- ✓ Memory-safe operation (<100KB)

## Next Steps

1. **Understand the system**: Read @tuning.md section "Visual Effects Timeline"
2. **Make first tweak**: Try "Make LEDs Brighter" above
3. **Debug as needed**: Consult @troubleshooting.md
4. **Deep dive**: See @visual-patterns.md for effect gallery
