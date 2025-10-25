# LED Tuning & Parameter Guide v2.0

Comprehensive parameter reference for rwc.rb / rwcz.rb LED visualization customization (New PAD History Strategy).

## Base Lighting Control

### Problem: Base Lighting Too Bright

**Root cause**: Base RGB value too high (blinding when all 60 LEDs lit)

**Solution: Reduce base brightness**
```ruby
# In LED update loop, line ~109 in rwcz.rb:
# Original:
r = g = b = 0x10  # 16/255 = 6% brightness

# Dimmer options:
r = g = b = 0x08  # 3% brightness (very subtle)
r = g = b = 0x0C  # 5% brightness (middle ground)
```

### Problem: Base Lighting Too Dim

**Root cause**: Can't see stage lighting effect, LEDs look off

**Solution: Increase base brightness**
```ruby
# Brighter options:
r = g = b = 0x18  # 9% brightness
r = g = b = 0x20  # 12% brightness (quite visible)
r = g = b = 0x30  # 19% brightness (strong stage presence)
```

**Warning**: Values above `0x40` may compete with green highlighting

---

## Green Highlighting Control

### Problem: Green Too Intense (Blinding)

**Root cause**: Full 0xFF green overpowering

**Solution 1: Reduce green intensity**
```ruby
# In LED update loop, line ~105 in rwcz.rb:
# Original:
g = 0xFF  # 100% green

# Softer options:
g = 0xC0  # 75% green (still vibrant)
g = 0xA0  # 63% green (balanced)
g = 0x80  # 50% green (subtle highlight)
```

**Solution 2: Keep green, reduce red/blue**
```ruby
# If green is OK but motion colors too strong:
r = ($current_color[0] / 2).to_i  # Halve red intensity
b = ($current_color[1] / 2).to_i  # Halve blue intensity
g = 0xFF  # Keep green strong
```

### Problem: Green Not Standing Out

**Root cause**: Green and base lighting too similar

**Solution: Increase contrast**
```ruby
# Option 1: Stronger green
g = 0xFF  # Already max

# Option 2: Dimmer base lighting
r = g = b = 0x08  # Was 0x10 (increase contrast)

# Option 3: Both
# Set base to 0x08, keep green at 0xFF
# Result: 16x brightness difference (very clear)
```

---

## PAD History Behavior

### Problem: Too Many PADs Highlighted (Confusing)

**Root cause**: History size too large (remembering too many PADs)

**Solution: Reduce history size**
```ruby
# Line 40 in rwcz.rb:
# Original:
$pad_history=Array.new(5, nil)  # Remember 5 PADs

# Smaller options:
$pad_history=Array.new(3, nil)  # Only last 3 PADs (focused)
$pad_history=Array.new(4, nil)  # Last 4 PADs (moderate)

# IMPORTANT: Also update ring buffer size on line 66:
$history_idx = ($history_idx + 1) % 3  # Match history size!
```

### Problem: Not Enough PADs Highlighted

**Root cause**: History size too small (PADs disappear too fast)

**Solution: Increase history size**
```ruby
# Larger options:
$pad_history=Array.new(7, nil)  # Last 7 PADs (generous)
$pad_history=Array.new(10, nil)  # Last 10 PADs (very inclusive)

# IMPORTANT: Update ring buffer:
$history_idx = ($history_idx + 1) % 7  # Match history size!
```

**Memory note**: Each additional history slot = +4 bytes (negligible)

---

## Acceleration Response Tuning

### Red Component (Movement Speed)

#### Problem: Red Too Sensitive (Flashes on Tiny Movements)

**Root cause**: Speed clamp range too narrow

**Solution: Increase speed max**
```ruby
# Line 86 in rwcz.rb:
# Original:
red = (speed.clamp(0,300) * 255 / 300).to_i

# Less sensitive options:
red = (speed.clamp(0,400) * 255 / 400).to_i  # Need faster motion for red
red = (speed.clamp(0,500) * 255 / 500).to_i  # Very fast motion required
```

#### Problem: Red Not Sensitive Enough (Never Shows Red)

**Root cause**: Speed clamp range too wide

**Solution: Decrease speed max**
```ruby
# More sensitive options:
red = (speed.clamp(0,200) * 255 / 200).to_i  # Easier to trigger red
red = (speed.clamp(0,150) * 255 / 150).to_i  # Very easy (even gentle motion)
```

#### Problem: Red Always Maxed Out

**Root cause**: Speed calculation includes noise

**Solution: Add minimum threshold**
```ruby
# Add speed threshold:
speed = (ax-$prev_accel[0]).abs + (ay-$prev_accel[1]).abs + (az-$prev_accel[2]).abs
speed = 0 if speed < 20  # Ignore small jitter
red = (speed.clamp(0,300) * 255 / 300).to_i
```

### Blue Component (Vertical Motion)

#### Problem: Blue Too Sensitive (Always Blue-Tinted)

**Root cause**: Z-axis clamp range too narrow

**Solution: Increase Z max**
```ruby
# Line 89 in rwcz.rb:
# Original:
blue = (az.abs.clamp(0,200) * 255 / 200).to_i

# Less sensitive options:
blue = (az.abs.clamp(0,300) * 255 / 300).to_i  # Need more tilt for blue
blue = (az.abs.clamp(0,400) * 255 / 400).to_i  # Very high tilt required
```

#### Problem: Blue Never Appears

**Root cause**: Z-axis clamp range too wide

**Solution: Decrease Z max**
```ruby
# More sensitive options:
blue = (az.abs.clamp(0,150) * 255 / 150).to_i  # Easier to trigger blue
blue = (az.abs.clamp(0,100) * 255 / 100).to_i  # Very easy (slight tilt)
```

#### Problem: Blue Direction Inverted

**Symptom**: Tilting up gives less blue, tilting down gives more blue

**Solution: Negate Z-axis**
```ruby
# Original:
blue = (az.abs.clamp(0,200) * 255 / 200).to_i

# Inverted (use negative Z):
blue = ((-az).abs.clamp(0,200) * 255 / 200).to_i
```

---

## Acceleration Sampling Rate

### Problem: Color Changes Too Jerky

**Root cause**: Sampling rate too slow (15ms = 66Hz)

**Solution: Sample more frequently**
```ruby
# Line 78 in rwcz.rb:
# Original:
if $tick % 15 == 0 && $u  # Every 15ms

# Faster options:
if $tick % 10 == 0 && $u  # Every 10ms (100Hz, smoother)
if $tick % 5 == 0 && $u   # Every 5ms (200Hz, very smooth)
```

**Warning**: Faster sampling = slightly higher CPU usage

### Problem: Color Updates Laggy (High CPU)

**Root cause**: Sampling rate too fast

**Solution: Sample less frequently**
```ruby
# Slower options:
if $tick % 20 == 0 && $u  # Every 20ms (50Hz, still smooth)
if $tick % 30 == 0 && $u  # Every 30ms (33Hz, acceptable)
if $tick % 50 == 0 && $u  # Every 50ms (20Hz, sluggish but low CPU)
```

---

## Custom Color Mappings

### Swap Axes

```ruby
# Original:
# Red = Speed (3-axis combined)
# Blue = Vertical (Z-axis)

# Swap to:
# Red = Horizontal (X-axis)
# Blue = Depth (Y-axis)

# Line 84-89 replacement:
# Red: X-axis absolute value
red = (ax.abs.clamp(0,200) * 255 / 200).to_i

# Blue: Y-axis absolute value
blue = (ay.abs.clamp(0,200) * 255 / 200).to_i
```

### Use Rotation Instead of Speed

```ruby
# Red = Rotation around Z-axis (yaw)
# Requires more complex calculation (not included in current implementation)
# For simple tilt-based red:
red = ((ax.abs + ay.abs).clamp(0,300) * 255 / 300).to_i  # XY plane tilt
```

### Add Yellow/Magenta/Cyan

```ruby
# Current: Only green (PAD history) + red (speed) + blue (vertical)
# To add yellow (red + green):
#   - Keep green at 0xFF for history PADs
#   - Increase red for history PADs when moving fast
# To add cyan (green + blue):
#   - Keep green at 0xFF for history PADs
#   - Increase blue for history PADs when tilting up
# (These happen automatically with current implementation!)
```

---

## Memory Optimization

If approaching Out of Memory:

### Option 1: Reduce History Size
```ruby
# Line 40:
$pad_history=Array.new(3, nil)  # Was 5 (saves 8 bytes)
```

### Option 2: Reduce Accel Precision
```ruby
# Line 80-82: Use fewer bits
ax = (a[:x] * 50).to_i  # Was * 100 (half precision, saves calculation)
ay = (a[:y] * 50).to_i
az = (a[:z] * 50).to_i

# Adjust clamp ranges accordingly:
red = (speed.clamp(0,150) * 255 / 150).to_i  # Half of original 300
blue = (az.abs.clamp(0,100) * 255 / 100).to_i  # Half of original 200
```

### Option 3: Disable Acceleration (Static Colors)
```ruby
# Line 78: Comment out acceleration sampling
# if $tick % 15 == 0 && $u
#   ...
# end

# Line 104-106: Use fixed colors
r = 0x00  # No red
g = 0xFF  # Always green for history PADs
b = 0x00  # No blue

# Result: History-only highlighting (no motion colors)
```

---

## CPU Optimization

If loop time exceeds 1ms:

### Option 1: Cache DRUM_LED.index Lookups
```ruby
# Create reverse lookup table at initialization:
# (Before loop)
$led_to_pad = {}
DRUM_LED.each_with_index {|led_pos, pad_idx| $led_to_pad[led_pos] = pad_idx if led_pos}

# In LED update loop (line 100):
pad_idx = $led_to_pad[i]  # Fast hash lookup instead of array scan
```

### Option 2: Update LEDs Less Frequently
```ruby
# Line 117: Update LED every 2ms instead of 1ms
if $tick % 2 == 0
  $led.show_hex(*$co)
end
```

### Option 3: Reduce History Checks
```ruby
# Pre-compute history set for faster lookup:
# (After PAD hit, line 68)
$history_set = $pad_history.compact  # Remove nils once

# In LED update loop (line 102):
if pad_idx && $history_set.include?(36 + pad_idx)  # Faster than repeated compact
```

---

## Testing Checklist

After each tuning change:

- [ ] Base lighting visible but not blinding
- [ ] Green highlights clearly distinguish history PADs
- [ ] Red appears on fast motion (not on stillness)
- [ ] Blue appears on upward tilt (not on horizontal)
- [ ] History updates correctly when PAD hit
- [ ] Old PADs removed from history after N hits
- [ ] Loop time still ~1ms (no stuttering)
- [ ] No Out of Memory errors on build
- [ ] Colors intuitive for audience

---

## Quick Presets

### "Subtle Stage" Preset
```ruby
r = g = b = 0x08  # Very dim base
g = 0xC0  # Softer green (history PADs)
red = (speed.clamp(0,400) * 255 / 400).to_i  # Less red
blue = (az.abs.clamp(0,300) * 255 / 300).to_i  # Less blue
# Result: Understated, elegant lighting
```

### "High Contrast" Preset
```ruby
r = g = b = 0x08  # Very dim base
g = 0xFF  # Full green (history PADs)
red = (speed.clamp(0,200) * 255 / 200).to_i  # More red
blue = (az.abs.clamp(0,150) * 255 / 150).to_i  # More blue
# Result: Dramatic, high-energy lighting
```

### "Ambient Glow" Preset
```ruby
r = g = b = 0x20  # Bright base
g = 0xA0  # Moderate green (history PADs)
red = (speed.clamp(0,500) * 255 / 500).to_i  # Very subtle red
blue = (az.abs.clamp(0,400) * 255 / 400).to_i  # Very subtle blue
# Result: Soft, immersive ambient lighting
```

### "Performance Tracker" Preset
```ruby
$pad_history=Array.new(10, nil)  # Remember 10 PADs
r = g = b = 0x10  # Normal base
g = 0xFF  # Full green (history PADs)
red = 0x00  # No red (disable speed)
blue = 0x00  # No blue (disable tilt)
# Result: Pure PAD tracking, no motion effects
```

---

## Advanced: Dynamic Brightness

### Goal: Brighten green on PAD hit, dim over time

**Current Implementation**: Green is constant (0xFF) while in history

**Enhancement**: Track hit time, fade green over history duration

```ruby
# This requires significant changes:
# 1. Store hit time with each history entry
# 2. Calculate age of each PAD in history
# 3. Reduce green based on age

# Example (not included in current rwcz.rb):
$pad_history = Array.new(5) { {note: nil, time: 0} }

# On PAD hit:
$pad_history[$history_idx] = {note: cmd, time: $tick}

# In LED update:
history_entry = $pad_history.find {|h| h[:note] == 36 + pad_idx}
if history_entry
  age = $tick - history_entry[:time]
  green_fade = (255 * (1 - age.to_f / 5000)).to_i.clamp(0x80, 0xFF)
  g = green_fade  # Fades from 0xFF to 0x80 over 5 seconds
end
```

**Memory cost**: +40 bytes (5 timestamps)
**CPU cost**: Moderate (age calculation per LED)

---

## Troubleshooting Common Tuning Mistakes

❌ **Forgot to update ring buffer modulo**
```ruby
$pad_history=Array.new(7, nil)  # Changed to 7
$history_idx = ($history_idx + 1) % 5  # Still using 5! ❌
# Result: Array index out of bounds
```
✅ **Fix**: `$history_idx = ($history_idx + 1) % 7`

❌ **Base lighting brighter than green**
```ruby
r = g = b = 0x80  # Base = 128
g = 0x60  # History green = 96 ❌
# Result: History PADs dimmer than non-history!
```
✅ **Fix**: Ensure `green_history > base_rgb`

❌ **Red/Blue exceed 0xFF**
```ruby
red = (speed * 255 / 100).to_i  # If speed=300, red=765 ❌
# Result: Color wraps, unexpected values
```
✅ **Fix**: Always use `.clamp(0, 255)` or clamp before multiplication

---

## Parameter Relationships

```
Base Brightness ↑ → Contrast with Green ↓
Green Intensity ↑ → Contrast with Base ↑
History Size ↑ → More LEDs green → Visual complexity ↑
Speed Max ↑ → Red harder to trigger → Subtler motion effect
Z Max ↑ → Blue harder to trigger → Subtler tilt effect
Sample Rate ↑ → Smoother color transitions → Slightly higher CPU
```

**Golden Rule**: Always test incrementally. Change one parameter at a time, verify effect before next change.
