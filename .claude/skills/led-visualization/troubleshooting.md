# LED Troubleshooting Guide v2.0

Solutions for common LED visualization issues in rwc.rb / rwcz.rb (New PAD History Strategy).

## Hardware Issues

### Problem: LEDs Not Lighting at All

**Symptom:** No light from any LED, even base lighting missing on startup.

**Diagnosis steps:**

1. **Verify connection**
   - GPIO 22 → WS2812 DIN physically connected?
   - 5V power to LED strip?
   - GND common between ESP32 and LED strip?
   ```bash
   # Check GPIO 22 is not in use elsewhere
   grep -r "GPIO.*22\|pin.*22" src_components/
   ```

2. **Test RMTDriver initialization**
   ```ruby
   # In rwcz.rb init section (after line 16):
   puts "Creating LED..."
   $led = WS2812.new(RMTDriver.new(22))
   puts "LED created: #{$led.class}"
   sleep_ms(50)
   ```

3. **Send test pattern**
   ```ruby
   # After init, add (before loop):
   puts "Testing LED with red..."
   test_color = Array.new(60, 0xFF0000)  # All red
   $led.show_hex(*test_color)
   sleep_ms(2000)  # Hold for 2 seconds
   puts "Test done, starting main loop"
   ```
   - If LEDs light red: Hardware OK, issue in main loop
   - If still dark: RMTDriver or power issue

**Solutions:**

| Scenario | Fix |
|----------|-----|
| LEDs don't light with test | Check 5V power to strip |
| LEDs light with test, not during main loop | Loop code overwrites color (check LED update section) |
| Some LEDs dark, some light | LED strip wiring broken (replace segment) |
| Random colors instead of expected | Data line signal issues (shorten cable, add 330Ω resistor) |

---

### Problem: LEDs Flicker or Strobe Unexpectedly

**Symptom:** LEDs randomly flash or blink erratically.

**Diagnosis:**

1. **Check UART interference**
   ```ruby
   # Add timing check in UART section:
   start_time = $tick
   while $pc.bytes_available > 0
     data = $pc.read(1)
     # ... process ...
   end
   elapsed = $tick - start_time
   puts "UART took: #{elapsed}ms" if elapsed > 5
   ```
   - If > 5ms: PC UART blocking main loop

2. **Check I2C blocking**
   ```ruby
   # Time accelerometer read (line 78):
   if $tick % 15 == 0 && $u
     start_time = $tick
     a = $u.acceleration
     elapsed = $tick - start_time
     puts "Accel read: #{elapsed}ms" if elapsed > 10
   end
   ```
   - If > 10ms: I2C communication issue

**Solutions:**

1. **Skip accel read more frequently**
   ```ruby
   if $tick % 30 == 0 && $u  # Was 15 (read every 30ms instead)
     # ... accel code ...
   end
   ```

2. **Use non-blocking UART read**
   ```ruby
   # Already non-blocking in rwcz.rb (line 54):
   while $pc.bytes_available > 0  # ✓ Only reads if data available
     data = $pc.read(1)
   end
   ```

3. **Reduce WS2812 update rate**
   ```ruby
   # Line 117: Update every 2ms instead of 1ms
   if $tick % 2 == 0
     $led.show_hex(*$co)
   end
   ```

---

## Base Lighting Issues

### Problem: No Base Lighting (All LEDs Off When Not Playing)

**Symptom:** LEDs are completely off when no PADs are being hit.

**Diagnosis:**

1. **Check base lighting initialization**
   ```ruby
   # Line 17 in rwcz.rb:
   $co=Array.new(60, 0x101010)  # Should be 0x101010, NOT 0
   puts "Base lighting: #{$co[0].to_s(16)}"  # Should print "101010"
   ```

2. **Check LED update loop**
   ```ruby
   # Line 109: Ensure base lighting set correctly
   puts "LED[#{i}] base: r=#{r} g=#{g} b=#{b}" if i == 0 && $tick % 100 == 0
   # Should show: r=16 g=16 b=16 (0x10 = 16)
   ```

**Solutions:**

| Root Cause | Fix |
|-----------|-----|
| Array initialized to 0 | Change line 17: `Array.new(60, 0x101010)` |
| LED update overwrites base | Verify line 109 sets `r = g = b = 0x10` |
| Base too dim to see | Increase to `0x20` or `0x30` (see @tuning.md) |

---

### Problem: Base Lighting Too Bright/Dim

**Symptom:** All LEDs blinding or barely visible.

**Solution:** See @tuning.md section "Base Lighting Control"

Quick fixes:
```ruby
# Too bright → reduce (line 109):
r = g = b = 0x08  # Was 0x10

# Too dim → increase (line 109):
r = g = b = 0x20  # Was 0x10
```

---

## PAD History Issues

### Problem: Green Highlight Not Appearing

**Symptom:** Hit PAD but corresponding LED stays white, doesn't turn green.

**Diagnosis:**

1. **Check PAD history updates**
   ```ruby
   # Line 68: Add debug output
   puts "PAD:#{cmd} history=#{$pad_history.compact.inspect}"
   # Should show PAD note added to history
   ```

2. **Check DRUM_LED mapping**
   ```ruby
   # Line 7: Verify DRUM_LED array
   puts "PAD 36 → LED #{DRUM_LED[0]}"  # Should print "0"
   puts "PAD 38 → LED #{DRUM_LED[2]}"  # Should print "1"
   ```

3. **Check history lookup in LED update**
   ```ruby
   # Line 100-102: Add debug
   if i == 0 && $tick % 100 == 0
     pad_idx = DRUM_LED.index(i)
     puts "LED[0] → PAD idx=#{pad_idx}, in history? #{$pad_history.include?(36 + pad_idx) if pad_idx}"
   end
   ```

**Solutions:**

| Root Cause | Fix |
|-----------|-----|
| History not updated | Verify line 65-66 executes when PAD hit |
| DRUM_LED mapping wrong | Check line 7 array (PAD 36→LED 0, 38→LED 1, etc.) |
| History check failing | Verify line 102: `$pad_history.include?(36 + pad_idx)` |
| Green value wrong | Verify line 105: `g = 0xFF` |

---

### Problem: History Not Updating (Same PADs Always Green)

**Symptom:** Hit new PADs but old PADs stay green, history not rotating.

**Diagnosis:**

1. **Check ring buffer logic**
   ```ruby
   # Line 65-66:
   $pad_history[$history_idx] = cmd
   $history_idx = ($history_idx + 1) % 5
   puts "History idx: #{$history_idx}, history: #{$pad_history.inspect}"
   ```
   - $history_idx should cycle 0→1→2→3→4→0...

2. **Check modulo matches array size**
   ```ruby
   # If history size changed:
   $pad_history=Array.new(7, nil)  # Size 7
   $history_idx = ($history_idx + 1) % 5  # ❌ Still using 5!
   # Should be:
   $history_idx = ($history_idx + 1) % 7  # ✓ Match size
   ```

**Solutions:**

1. **Fix ring buffer modulo**
   ```ruby
   # Line 66: Ensure modulo matches history size
   HISTORY_SIZE = 5
   $pad_history=Array.new(HISTORY_SIZE, nil)  # Line 40
   $history_idx = ($history_idx + 1) % HISTORY_SIZE  # Line 66
   ```

2. **Reset history if corrupted**
   ```ruby
   # Add to initialization or debug section:
   $pad_history = Array.new(5, nil)
   $history_idx = 0
   puts "History reset"
   ```

---

### Problem: Too Many/Too Few PADs Highlighted

**Symptom:** More/fewer than expected PADs showing green.

**Solution:** See @tuning.md section "PAD History Behavior"

Quick fix:
```ruby
# Line 40: Adjust history size
$pad_history=Array.new(3, nil)  # Only last 3 PADs
# or
$pad_history=Array.new(7, nil)  # Last 7 PADs

# IMPORTANT: Update line 66 to match:
$history_idx = ($history_idx + 1) % 3  # Match size!
```

---

## Acceleration Color Issues

### Problem: Colors Not Responding to Motion

**Symptom:** LEDs always same color regardless of ATOM movement.

**Diagnosis:**

1. **Check accelerometer initialization**
   ```ruby
   # Line 21-30: Check for errors
   begin
     $i2c=I2C.new(...)
     $u=MPU6886.new($i2c)
     puts "MPU initialized: #{$u.class}"
   rescue => e
     puts "MPU init failed: #{e.message}"  # Should NOT see this
     $u=nil
   end
   ```

2. **Check I2C lines**
   - GPIO 21 (SDA) connected to MPU6886 SDA?
   - GPIO 25 (SCL) connected to MPU6886 SCL?
   - 3.3V and GND connected?

3. **Test acceleration readings**
   ```ruby
   # Line 79-82: Add debug
   if $tick % 15 == 0 && $u
     a = $u.acceleration
     ax = (a[:x] * 100).to_i
     ay = (a[:y] * 100).to_i
     az = (a[:z] * 100).to_i
     puts "Accel: ax=#{ax}, ay=#{ay}, az=#{az}" if $tick % 150 == 0
     # Should change when ATOM tilted
   end
   ```

**Solutions:**

| Root Cause | Fix |
|-----------|-----|
| MPU not initialized | Check I2C wiring, 3.3V power |
| Accel not being read | Verify line 78: `if $tick % 15 == 0 && $u` executes |
| Colors not updating | Check line 91-92: `$current_color = [red, blue]` |
| $u is nil | MPU init failed, check rescue block output |

---

### Problem: Wrong Colors (e.g., Blue When Moving Fast)

**Symptom:** Fast motion gives blue instead of red, or vice versa.

**Diagnosis:**

1. **Check color assignment**
   ```ruby
   # Line 91: Verify assignment
   $current_color = [red, blue]  # Index 0=red, 1=blue

   # Line 104, 106: Verify usage
   r = $current_color[0]  # Should be red
   b = $current_color[1]  # Should be blue
   ```

2. **Check calculation**
   ```ruby
   # Line 85-89: Add debug
   puts "Speed=#{speed} → red=#{red}"
   puts "Z=#{az} → blue=#{blue}"
   ```

**Solutions:**

| Symptom | Fix |
|---------|-----|
| Blue on fast motion | Swap line 91: `$current_color = [blue, red]` → `[red, blue]` |
| Red on tilt | Check line 86 uses `speed`, not `az` |
| Colors inverted | Swap indices on line 104/106 |

---

### Problem: Red/Blue Always Zero or Always Max

**Symptom:** Red component stuck at 0x00 or 0xFF regardless of motion.

**Diagnosis:**

1. **Check clamping**
   ```ruby
   # Line 86:
   red = (speed.clamp(0,300) * 255 / 300).to_i
   puts "Speed raw: #{speed}, clamped: #{speed.clamp(0,300)}, red: #{red}"
   ```

2. **Check previous acceleration**
   ```ruby
   # Line 92: Verify $prev_accel updates
   puts "Prev: #{$prev_accel.inspect}"
   $prev_accel = [ax, ay, az]
   puts "New: #{$prev_accel.inspect}"
   ```

**Solutions:**

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| Red always 0 | `$prev_accel` not updating | Verify line 92 executes |
| Red always 255 | Clamp range too narrow | Increase to 400 or 500 (see @tuning.md) |
| Blue always 0 | Z-axis not changing | Tilt ATOM up/down, check sensor |
| Blue always 255 | Clamp range too narrow | Increase to 300 or 400 (see @tuning.md) |

---

## Performance Issues

### Problem: Out of Memory During Build

**Symptom:** Build fails with "insufficient memory" or stack overflow.

**Diagnosis:**

1. **Check code size**
   ```bash
   wc -l src_components/R2P2-ESP32/storage/home/rwcz.rb
   # Should be ~120 lines (new strategy is compact!)
   ```

2. **Check memory allocations**
   ```ruby
   # rwcz.rb memory usage:
   $co = Array.new(60, 0x101010)      # ~240 bytes
   $pad_history = Array.new(5, nil)  # ~20 bytes
   $prev_accel = [0,0,0]             # ~12 bytes
   $current_color = [0,0]            # ~8 bytes
   # Total: ~280 bytes (very small!)
   ```

**Solutions:**

1. **Reduce history size** (if desperate)
   ```ruby
   $pad_history=Array.new(3, nil)  # Was 5 (saves 8 bytes)
   ```

2. **Disable acceleration** (if desperate)
   ```ruby
   # Line 21-30: Comment out MPU init
   # $u = nil

   # Line 78-95: Comment out accel sampling
   # Result: Static green highlighting only
   ```

---

### Problem: Loop Time Exceeds 1ms (Stuttering LEDs)

**Symptom:** LED updates appear jerky, loop can't keep pace.

**Diagnosis:**

1. **Measure loop time**
   ```ruby
   if $tick % 1000 == 0
     puts "Tick: #{$tick} (should increase by ~1000/sec)"
   end
   ```

2. **Profile LED update**
   ```ruby
   # Before line 98:
   update_start = $tick
   60.times do |i|
     # ... LED update ...
   end
   update_elapsed = $tick - update_start
   puts "LED update: #{update_elapsed}ms" if update_elapsed > 1
   ```

**Solutions:**

1. **Cache DRUM_LED.index lookup** (see @tuning.md "CPU Optimization")
   ```ruby
   # Before loop:
   $led_to_pad = {}
   DRUM_LED.each_with_index {|led_pos, pad_idx| $led_to_pad[led_pos] = pad_idx if led_pos}

   # In loop (line 100):
   pad_idx = $led_to_pad[i]  # Faster!
   ```

2. **Update LEDs less frequently**
   ```ruby
   # Line 117:
   if $tick % 2 == 0  # Every 2ms
     $led.show_hex(*$co)
   end
   ```

3. **Sample acceleration less frequently**
   ```ruby
   # Line 78:
   if $tick % 30 == 0 && $u  # Was 15 (half frequency)
   ```

---

## Debug Output Template

When troubleshooting, add this diagnostic block:

```ruby
# After line 48, add:
if $tick % 500 == 0  # Every 500ms
  puts "=== LED DEBUG v2 ==="
  puts "Tick: #{$tick}"
  puts "History: #{$pad_history.compact.inspect}"
  puts "History idx: #{$history_idx}"
  if $u
    puts "Accel: #{$prev_accel.inspect}"
    puts "Colors: R=#{$current_color[0]} B=#{$current_color[1]}"
  else
    puts "Accel: disabled (MPU failed)"
  end
  puts "LED[0]: 0x#{$co[0].to_s(16)}"
  puts "LED[1]: 0x#{$co[1].to_s(16)}"
end
```

This provides key info for remote debugging.

---

## Common Error Messages

### "MPU6886 Error: ..."

**Cause**: Accelerometer initialization failed

**Fix**:
- Check I2C wiring (GPIO 21/25)
- Verify 3.3V power to MPU6886
- Check I2C address (should be 0x68)

**Workaround**: System continues without acceleration colors (static green/white only)

---

### "Array index out of bounds"

**Cause**: Ring buffer modulo mismatch

**Fix**:
```ruby
# Ensure line 66 modulo matches line 40 array size:
$pad_history=Array.new(5, nil)  # Line 40
$history_idx = ($history_idx + 1) % 5  # Line 66 (must match!)
```

---

### "LED not responding" (silent failure)

**Cause**: RMTDriver or WS2812 initialization failed

**Diagnosis**:
```ruby
# After line 16:
puts "LED class: #{$led.class}"  # Should show WS2812
```

**Fix**:
- Check GPIO 22 connection
- Verify 5V power to LED strip
- Try different RMT channel (if available)

---

## Verification Checklist

After fixing issues, verify:

- [ ] Base lighting appears on startup (dim white, all 60 LEDs)
- [ ] Hitting PAD adds to history (green highlight appears)
- [ ] Hitting 6th PAD removes oldest from history (first PAD goes white)
- [ ] Fast motion adds red tint to history PADs
- [ ] Upward tilt adds blue tint to history PADs
- [ ] Loop runs at ~1000 Hz (1ms per iteration)
- [ ] No flicker or stuttering
- [ ] Debug output shows correct values

---

## Emergency Reset

If completely broken, start fresh:

```ruby
# Replace rwcz.rb with known-good version from git:
git checkout src_components/R2P2-ESP32/storage/home/rwcz.rb

# Or rebuild from scratch (see SKILL.md)
```

---

## Get Help

If issues persist:

1. Collect debug output (use template above)
2. Note LED behavior (which issue from this guide?)
3. Check hardware connections
4. Review @tuning.md for parameter adjustments
5. Consult @SKILL.md for system overview

**Most issues are wiring or parameter tuning!**
