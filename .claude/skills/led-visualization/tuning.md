# LED Tuning & Parameter Guide

Comprehensive parameter reference for rwc.rb LED visualization customization.

## Brightness Control

### Problem: LEDs Too Bright

**Root cause**: Velocity scaling too aggressive

**Solution 1: Reduce scaling**
```ruby
# In light_flash(), line ~102:
# Original:
bri = (vel * 2).clamp(0, 255)

# Option 1 - 50% reduction:
bri = vel

# Option 2 - 25% reduction:
bri = (vel * 1.5).clamp(0, 255)

# Option 3 - gradual (logarithmic):
bri = (Math.sqrt(vel) * 16).clamp(0, 255)
```

**Solution 2: Reduce center saturation**
```ruby
# In saturation array, increase 255 to 200:
[
  [pos, 200, bri],  # Was 255
  [pos-1, 179, bri],
  ...
]
# Reduces max brightness by ~20%
```

### Problem: LEDs Too Dim

**Root cause**: Velocity scaling too low OR fade too aggressive

**Solution 1: Increase scaling**
```ruby
# Original: bri = (vel * 2)
# Brighter options:
bri = (vel * 2.5).clamp(0, 255)
bri = (vel * 3).clamp(0, 255)
```

**Solution 2: Slow fade decay**
```ruby
# In fade_leds(), change decay rate:
# Original: $co[i] * 97 / 100  (3% decay)
# Slower:
$co[i] = $co[i] * 98 / 100  # 2% decay (longer glow)
$co[i] = $co[i] * 99 / 100  # 1% decay (very long glow)
```

## Color & Saturation

### Color Saturation Array

Current design uses 4-level saturation:

```
Position  Distance  Saturation  RGB Mixing
--------  --------  ----------  ----------
pos       0         255 (100%)  Pure color
pos±1     1         179 (70%)   70% color + 30% white
pos±2     2         102 (40%)   40% color + 60% white
pos±3     3         51 (20%)    20% color + 80% white
```

### Problem: Color Fade Too Fast

LEDs become white too quickly at edges

**Solution: Increase saturation at distance**
```ruby
# Original array: [255, 179, 102, 51]
# More vibrant (slower white convergence):
[255, 200, 150, 100]

# Or custom per-position:
[
  [pos, 255, bri],    # Was 255
  [pos-1, 200, bri],  # Was 179 (more vibrant)
  [pos+1, 200, bri],
  [pos-2, 130, bri],  # Was 102
  [pos+2, 130, bri],
  [pos-3, 80, bri],   # Was 51
  [pos+3, 80, bri]
]
```

### Problem: Color Fade Too Slow

LEDs stay colored too long, white effect less prominent

**Solution: Decrease saturation at distance**
```ruby
# Original: [255, 179, 102, 51]
# Faster white convergence:
[255, 150, 80, 20]

# Or very fast (almost instant white):
[255, 100, 40, 10]
```

## Tilt Response (Acceleration Sensor)

### Problem: Colors Not Changing Enough with Tilt

ATOM rotation causes minimal color shift

**Solution: Amplify tilt response** (narrow clamp range)
```ruby
# In get_color(), change clamp:
# Original:
dx = dx.clamp(-200, 200)

# More responsive (narrower range):
dx = dx.clamp(-150, 150)  # Same tilt = bigger color change
dy = dy.clamp(-150, 150)
dz = dz.clamp(-150, 150)

# Very responsive:
dx = dx.clamp(-100, 100)  # Extreme color shift per degree
```

### Problem: Colors Too Jumpy with Tilt

Minor movements cause dramatic color changes

**Solution: Dampen tilt response** (wider clamp range)
```ruby
# Original:
dx = dx.clamp(-200, 200)

# Less responsive (wider range):
dx = dx.clamp(-300, 300)  # More tilt = same color change
dy = dy.clamp(-300, 300)
dz = dz.clamp(-300, 300)

# Very smooth:
dx = dx.clamp(-500, 500)  # Huge tilt needed for color shift
```

### Problem: Wrong Color Direction on Tilt

Tilting forward produces magenta instead of green

**Solution: Check axis mapping or invert**
```ruby
# In get_color():
# Current (Y axis → Green):
g = ((dy + 200) * 255 / 400).to_i

# If inverted, negate:
g = ((-dy + 200) * 255 / 400).to_i

# Or swap axes entirely:
r = ((dy + 200) * 255 / 400).to_i  # Y→R
g = ((dx + 200) * 255 / 400).to_i  # X→G
b = ((dz + 200) * 255 / 400).to_i  # Z→B
```

## Fade Timing

### Fade Interval Table

| Loop Count | Time | Effect |
|-----------|------|--------|
| %8 | ~8ms | Very fast decay, sharp effects |
| %15 | ~15ms | Default, 60 FPS visual |
| %30 | ~30ms | Slower decay, longer glow |
| %50 | ~50ms | Very long glow, 1+ sec sustain |
| %100 | ~100ms | Extreme glow, cinema effect |

### Problem: LEDs Disappear Too Fast

**Solution: Increase fade interval**
```ruby
# In main loop, change condition:
# Original: if $lc % 15 == 0
# Slower:
if $lc % 30 == 0  # Half frequency = longer glow

# Much slower:
if $lc % 100 == 0  # 1/7 frequency = sustained effect
```

**Compensate decay rate:**
```ruby
# If using %100 interval, reduce decay to maintain look:
$co[i] = $co[i] * 99 / 100  # 1% decay instead of 3%

# If using %30 interval, can be more aggressive:
$co[i] = $co[i] * 95 / 100  # 5% decay
```

### Problem: LEDs Disappear Too Slowly

Ghosting effect, previous PAD still visible

**Solution: Decrease fade interval**
```ruby
# Original: if $lc % 15 == 0
# Faster:
if $lc % 8 == 0   # More frequent fades

# Very fast:
if $lc % 4 == 0   # Rapid decay
```

**Increase decay rate:**
```ruby
# If using %8 interval, use aggressive decay:
$co[i] = $co[i] * 94 / 100  # 6% decay per step

# If using %4 interval, very aggressive:
$co[i] = $co[i] * 90 / 100  # 10% decay per step
```

## LED Spread Range

### Spread Table

| Config | Range | LED Count | Effect |
|--------|-------|-----------|--------|
| ±1 | Center ±1 | 3 | Tight, sharp flash |
| ±2 | Center ±2 | 5 | Balanced |
| ±3 | Center ±3 | 7 | Default, generous glow |
| ±4 | Center ±4 | 9 | Wide ambient |
| ±5 | Center ±5 | 11 | Very wide, diffuse |

### Problem: LEDs Flash Too Concentrated

All light in 3 LEDs, feels cramped

**Solution: Increase spread**
```ruby
# Original (±3):
[
  [pos, 255, bri],
  [pos-1, 179, bri], [pos+1, 179, bri],
  [pos-2, 102, bri], [pos+2, 102, bri],
  [pos-3, 51, bri], [pos+3, 51, bri]
]

# Wider (±5):
[
  [pos, 255, bri],
  [pos-1, 179, bri], [pos+1, 179, bri],
  [pos-2, 102, bri], [pos+2, 102, bri],
  [pos-3, 51, bri], [pos+3, 51, bri],
  [pos-4, 25, bri], [pos+4, 25, bri],    # New
  [pos-5, 10, bri], [pos+5, 10, bri]     # New
]
```

### Problem: LEDs Flash Too Wide

Glow bleeds into neighboring PAD zones, confusing

**Solution: Decrease spread**
```ruby
# Original (±3)
# Tighter (±1):
[
  [pos, 255, bri],
  [pos-1, 179, bri], [pos+1, 179, bri]
  # Remove ±2, ±3 entries
]

# Very tight (center only):
[
  [pos, 255, bri]
  # Remove all surrounding
]
```

## Pseudo-Random Distribution

### Distribution Patterns

| Multiplier | Pattern | Uses |
|-----------|---------|------|
| 7 (default) | Uniform, period 60 | Balanced visual variety |
| 11 | Sparser, different sequence | Less repetition feel |
| 13 | Sparsest, long period | Maximum randomness |
| 3 | Dense, repeating | Predictable patterns |

### Change Pattern

```ruby
# In flash_drum(), change line ~130:
# Original:
pos2 = ($lc * 7 + note * 3) % 60

# Alternative patterns:
pos2 = ($lc * 11 + note * 3) % 60  # Different feel
pos2 = ($lc * 13 + note * 3) % 60  # Most varied
pos2 = ($lc * 17 + note * 5) % 60  # Custom multiplier
```

### Distribution Quality Check

Test if positions are roughly uniform:

```ruby
# Count hits per position (log during performance)
hits = Array.new(60, 0)
1000.times do |i|
  pos2 = ($lc * 7 + 40 * 3) % 60
  hits[pos2] += 1
  $lc += 1
end
# Expected: ~16-17 per position
# Min/Max should be within 10-20 range
```

## Collision Avoidance

### Problem: pos1 and pos2 Overlap

Two points light very close, visual confusion

**Solution: Increase avoidance distance**
```ruby
# In flash_drum():
# Original:
pos2 = (pos2 + 15) % 60 if (pos1 - pos2).abs < 5

# Stricter (no overlap if closer than 10):
pos2 = (pos2 + 15) % 60 if (pos1 - pos2).abs < 10

# Double-check overlap:
pos2 = (pos2 + 15) % 60 if (pos1 - pos2).abs < 5
pos2 = (pos2 + 30) % 60 if (pos1 - pos2).abs < 10
```

## Memory Optimization

If approaching Out of Memory:

### Option 1: Disable Accelerometer
```ruby
# In init_hardware():
$mpu = nil  # Skip initialization

# get_color() returns white
# No color response to tilt, but saves ~2KB
```

### Option 2: Reduce LED Count
```ruby
# Change LED array size (if hardware supports):
$co = Array.new(40, 0)  # 40 instead of 60

# Update spread boundaries:
next if p < 0 || p >= 40  # Was >= 60
```

### Option 3: Reduce Loop Count Precision
```ruby
# In main loop:
sleep_ms(2)  # 2ms instead of 1ms
# Adjust fade condition: if $lc % 7 == 0  (was %15)
```

## CPU Optimization

If loop time exceeds 1ms:

### Option 1: Skip Accel Reads
```ruby
# Only read accel every N fades:
if $lc % 30 == 0  # Read every 30ms
  c = get_color
end
# Reuse c for next 30ms until next read
```

### Option 2: Batch LED Updates
```ruby
# Show LED only every 2 iterations:
if $lc % 2 == 0
  $led.show_rgb(*rgb)
end
# Halves LED update overhead
```

### Option 3: Reduce Spread Loop
```ruby
# Use simpler spread (fewer positions):
# Original: 7 positions
# Simplified: 3 positions
[
  [pos, 255, bri],
  [pos-1, 150, bri], [pos+1, 150, bri]
]
```

## Testing Checklist

After each tuning change:

- [ ] Visual: Flash looks intentional, not accidental
- [ ] Color: Matches accel tilt direction (or intentional inversion)
- [ ] Fade: Glow persists as expected (not too fast/slow)
- [ ] Spread: Light reaches intended width
- [ ] Collision: pos1 and pos2 don't overlap unexpectedly
- [ ] Performance: Loop time still ~1ms, no stutter
- [ ] Memory: No Out of Memory errors on build
- [ ] Brightness: Not blinding, not invisible

## Quick Presets

### "Bright Flash" Preset
```ruby
bri = (vel * 3).clamp(0, 255)
if $lc % 10 == 0  # Faster fade
  $co[i] = $co[i] * 95 / 100  # 5% decay
end
# Result: Intense, sharp flashes
```

### "Soft Glow" Preset
```ruby
bri = vel
[255, 180, 110, 60]  # Softer saturation
if $lc % 25 == 0  # Slower fade
  $co[i] = $co[i] * 98 / 100  # 2% decay
end
# Result: Gentle, sustained light
```

### "High Contrast" Preset
```ruby
bri = (vel * 2.5).clamp(0, 255)
[255, 100, 30, 5]  # Fast white convergence
if $lc % 12 == 0  # Medium fade
  $co[i] = $co[i] * 96 / 100  # 4% decay
end
# Result: Sharp center, quick white edges
```
