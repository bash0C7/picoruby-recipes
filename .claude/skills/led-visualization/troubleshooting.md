# LED Troubleshooting Guide

Solutions for common LED visualization issues in rwc.rb.

## Hardware Issues

### Problem: LEDs Not Lighting at All

**Symptom:** No light from any LED, even during drum hits.

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
   # In rwc.rb init_hardware():
   puts "Creating LED..."
   $led = WS2812.new(RMTDriver.new(22))
   puts "LED created: #{$led.class}"
   sleep_ms(50)
   ```

3. **Send test pattern**
   ```ruby
   # After init, add:
   test_color = Array.new(60, 0xFF0000)  # All red
   $led.show_hex(*test_color)
   sleep_ms(1000)
   ```
   - If LEDs light red: Hardware OK, issue in main loop
   - If still dark: RMTDriver or power issue

**Solutions:**

| Scenario | Fix |
|----------|-----|
| LEDs don't light with test | Check 5V power to strip |
| LEDs light with test, not during performance | Loop code overwrites color (check fade) |
| Some LEDs dark, some light | LED strip wiring broken (replace segment) |
| Random colors instead of expected | Data line signal issues (shorten cable) |

---

### Problem: LEDs Flicker or Strobe Unexpectedly

**Symptom:** LEDs randomly flash or blink erratically.

**Diagnosis:**

1. **Check UART interference**
   ```ruby
   # Add timing check:
   start = Time.now
   $pc_uart.read  # May block
   elapsed = Time.now - start
   puts "UART read took: #{elapsed}ms"
   ```
   - If > 5ms: PC UART blocking main loop

2. **Check I2C blocking**
   ```ruby
   # Time accelerometer read:
   start = Time.now
   a = $mpu.acceleration
   elapsed = Time.now - start
   puts "Accel read: #{elapsed}ms"
   ```
   - If > 10ms: I2C communication issue

**Solutions:**

1. **Skip accel read more frequently**
   ```ruby
   if $lc % 60 == 0  # Read every 60ms instead of every loop
     c = get_color
   end
   ```

2. **Use non-blocking UART read**
   ```ruby
   # Instead of:
   data = $pc_uart.read  # May block

   # Use:
   if $pc_uart.bytes_available > 0
     data = $pc_uart.read(1)  # Read 1 byte only
   end
   ```

3. **Reduce WS2812 update rate**
   ```ruby
   # In main loop:
   if $lc % 2 == 0  # Update every 2ms instead of 1ms
     $led.show_rgb(*rgb)
   end
   ```

---

## Color Issues

### Problem: Colors Not Responding to Tilt

**Symptom:** LEDs always white, regardless of ATOM movement.

**Diagnosis:**

1. **Check accelerometer initialization**
   ```ruby
   # In init_hardware():
   begin
     $mpu = MPU6886.new(i2c_unit: :ESP32_I2C0, sda_pin: 21, scl_pin: 25, freq: 100000)
     puts "MPU initialized: #{$mpu.class}"
   rescue => e
     puts "MPU init failed: #{e.message}"
     $mpu = nil
   end
   ```

2. **Check I2C lines**
   - GPIO 21 (SDA) connected to MPU6886 SDA?
   - GPIO 25 (SCL) connected to MPU6886 SCL?
   - 4.7k pullup resistors present?
   ```bash
   # Check I2C address:
   # MPU6886 default: 0x68
   # If custom board: check datasheet
   ```

3. **Test acceleration readings**
   ```ruby
   # In main loop:
   if $lc % 100 == 0
     a = $mpu.acceleration
     puts "X:#{a[:x]}, Y:#{a[:y]}, Z:#{a[:z]}"
   end
   ```
   - Should show values like -1.0 to 1.0
   - Should change when ATOM tilted

4. **Check color calculation**
   ```ruby
   # Trace get_color():
   def get_color_debug
     return 0xFFFFFF unless $mpu
     a = $mpu.acceleration
     dx = (a[:x] * 100).to_i - $bx[0]
     puts "dx=#{dx}"  # Should be non-zero when tilted
     ...
   end
   ```

**Solutions:**

| Root Cause | Fix |
|-----------|-----|
| MPU not initialized | Check I2C wiring, address |
| Calibration wrong | Run 5-point baseline again |
| Clamp range wrong | Adjust clamp: ±200 → ±150 or ±300 |
| get_color returns white | Check return value in rescue block |

---

### Problem: Wrong Colors (Inverted Axes)

**Symptom:** Tilt forward → magenta (expect green), tilt right → yellow (expect cyan).

**Diagnosis:**

1. **Identify which axis is wrong**
   - Tilt forward (Y): expect green (0x00FF00), get magenta (0xFF00FF)?
     → Y axis inverted or misassigned
   - Tilt right (X): expect cyan (0x00FFFF), get yellow (0xFFFF00)?
     → X axis inverted or misassigned

2. **Check axis mapping** in `get_color()`:
   ```ruby
   r = ((dx + 200) * 255 / 400).to_i  # X → Red
   g = ((dy + 200) * 255 / 400).to_i  # Y → Green
   b = ((dz + 200) * 255 / 400).to_i  # Z → Blue
   ```

**Solutions:**

1. **Invert one axis** (negate delta):
   ```ruby
   # If Y is inverted:
   g = ((-dy + 200) * 255 / 400).to_i  # Negate dy

   # If X is inverted:
   r = ((-dx + 200) * 255 / 400).to_i
   ```

2. **Swap axes** (remap completely):
   ```ruby
   # If axes need swapping (X↔Y):
   r = ((dy + 200) * 255 / 400).to_i  # Y → Red
   g = ((dx + 200) * 255 / 400).to_i  # X → Green
   b = ((dz + 200) * 255 / 400).to_i  # Z → Blue (unchanged)
   ```

3. **Re-calibrate baseline**
   ```ruby
   # Run calibration again:
   5.times do
     a = $mpu.acceleration
     puts "Before: X=#{a[:x]}, Y=#{a[:y]}, Z=#{a[:z]}"
     $bx[0] = (a[:x] * 100).to_i
     $bx[1] = (a[:y] * 100).to_i
     $bx[2] = (a[:z] * 100).to_i
     sleep_ms(100)
   end
   ```

---

## Brightness Issues

### Problem: LEDs Too Bright (Blinding)

**Symptom:** Even dim drum sounds create blinding flashes.

**Diagnosis:**

1. **Check velocity scaling**
   ```ruby
   # In light_flash(), check:
   bri = (vel * 2).clamp(0, 255)
   # vel = 127 (typical) → bri = 254 (nearly max)
   ```

2. **Check saturation array**
   ```ruby
   # Array values:
   [255, 179, 102, 51]  # 255 = full brightness at center
   ```

**Solutions:**

1. **Reduce velocity scaling** (see @tuning.md "Brightness Adjustment")
   ```ruby
   bri = vel  # 50% reduction
   # or
   bri = (vel * 1.5).clamp(0, 255)  # 25% reduction
   ```

2. **Reduce center saturation**
   ```ruby
   # Change [255, 179, 102, 51] to:
   [200, 160, 100, 50]  # 200 instead of 255
   ```

3. **Slow down fade** (longer decay = lower avg brightness)
   ```ruby
   if $lc % 20 == 0  # Was % 15
     $co[i] = $co[i] * 97 / 100
   end
   ```

---

### Problem: LEDs Too Dim

**Symptom:** Even loud drum hits barely visible.

**Diagnosis:**

1. **Check loop performance**
   ```ruby
   # Add timing:
   loop_start = Time.now
   # ... main loop code ...
   loop_elapsed = Time.now - loop_start
   if loop_elapsed > 2  # Should be <1ms
     puts "SLOW LOOP: #{loop_elapsed}ms"
   end
   ```
   - If loop is slow, LED updates lag

2. **Check fade rate**
   ```ruby
   if $lc % 15 == 0
     $co[i] = $co[i] * 97 / 100  # Is this running?
     puts "Fade executed"
   end
   ```

3. **Check velocity values**
   ```ruby
   # In flash_drum():
   puts "vel=#{vel}"  # Is it always 127?
   ```

**Solutions:**

1. **Increase velocity scaling**
   ```ruby
   bri = (vel * 3).clamp(0, 255)  # Was * 2
   ```

2. **Slow fade decay**
   ```ruby
   $co[i] = $co[i] * 98 / 100  # 2% decay instead of 3%
   $co[i] = $co[i] * 99 / 100  # Or 1% for longest glow
   ```

3. **Increase saturation**
   ```ruby
   # [255, 179, 102, 51] → higher values
   [255, 200, 150, 100]
   ```

4. **Optimize loop speed**
   - Check for blocking I2C reads
   - Skip accel reads more frequently
   - Reduce LED update frequency

---

## Position & Distribution Issues

### Problem: Same LED Positions Always Light

**Symptom:** Only PAD 0-7 light up, never see LEDs 16-59.

**Diagnosis:**

1. **Check pseudo-random formula**
   ```ruby
   # In flash_drum():
   pos2 = ($lc * 7 + note * 3) % 60
   # Is $lc incrementing? Is loop running?
   ```

2. **Check loop counter**
   ```ruby
   if $lc % 1000 == 0
     puts "Loop count: #{$lc}"  # Should increase continuously
   end
   ```

3. **Check collision avoidance**
   ```ruby
   pos2 = (pos2 + 15) % 60 if (pos1 - pos2).abs < 5
   # If always triggering, pos2 always same distance from pos1
   ```

**Solutions:**

1. **Increase pseudo-random coefficient**
   ```ruby
   # Change 7 to coprime multiplier:
   pos2 = ($lc * 11 + note * 3) % 60  # More variety
   # Or:
   pos2 = ($lc * 13 + note * 3) % 60  # Even more variety
   ```

2. **Verify distribution**
   ```ruby
   # Test distribution:
   hits = Array.new(60, 0)
   100.times do |i|
     pos2 = ($lc * 7 + 40 * 3) % 60
     hits[pos2] += 1
     $lc += 1
   end
   min = hits.min
   max = hits.max
   puts "Distribution: min=#{min}, max=#{max}, avg=#{100.0/60}"
   # Should be roughly 1-2 hits per position
   ```

3. **Increase collision offset**
   ```ruby
   # If collision avoidance causes clustering:
   pos2 = (pos2 + 20) % 60 if (pos1 - pos2).abs < 5  # Was 15
   ```

---

### Problem: Positions Too Close (Overlap)

**Symptom:** pos1 and pos2 light adjacent LEDs, creating confusion.

**Diagnosis:**

```ruby
# In flash_drum():
puts "pos1=#{pos1}, pos2=#{pos2}, dist=#{(pos1-pos2).abs}"
# Should usually see distance > 5
```

**Solutions:**

1. **Increase avoidance distance**
   ```ruby
   # Original:
   pos2 = (pos2 + 15) % 60 if (pos1 - pos2).abs < 5

   # More aggressive:
   pos2 = (pos2 + 15) % 60 if (pos1 - pos2).abs < 10
   ```

2. **Use different offset**
   ```ruby
   # Offset by 20 instead of 15:
   pos2 = (pos2 + 20) % 60 if (pos1 - pos2).abs < 5
   ```

---

## Memory & Performance Issues

### Problem: Out of Memory During Build

**Symptom:** Build fails with "insufficient memory" or stack overflow.

**Diagnosis:**

1. **Check code size**
   ```bash
   wc -l src_components/R2P2-ESP32/storage/home/rwc.rb
   # Should be <250 lines
   ```

2. **Identify large allocations**
   ```ruby
   # In rwc.rb:
   $co = Array.new(60, 0)       # ~240 bytes (OK)
   $mpu = MPU6886.new(...)      # ~1KB (OK)
   # Check for unexpected allocations
   ```

**Solutions:**

1. **Disable accelerometer**
   ```ruby
   $mpu = nil  # Skip init
   # get_color() returns 0xFFFFFF (white)
   ```

2. **Reduce LED count**
   ```ruby
   $co = Array.new(40, 0)  # 40 instead of 60
   # Adjust bounds: p >= 40 instead of 60
   ```

3. **Reduce loop resolution**
   ```ruby
   sleep_ms(2)  # Instead of 1ms
   # Adjust fade: if $lc % 7 == 0 (was %15)
   ```

---

### Problem: Loop Time Exceeds 1ms (Stuttering)

**Symptom:** LED updates appear jerky, loop can't keep pace.

**Diagnosis:**

1. **Measure loop time**
   ```ruby
   loop do
     start = Time.now
     # ... main loop code ...
     elapsed = Time.now - start
     if elapsed > 1  # milliseconds
       puts "SLOW: #{elapsed}ms"
     end
     sleep_ms(1)
   end
   ```

2. **Profile each operation**
   ```ruby
   # Time UART read:
   start = Time.now
   $pc_uart.read if $pc_uart.bytes_available > 0
   puts "UART: #{(Time.now - start)*1000}ms"

   # Time LED update:
   start = Time.now
   $led.show_rgb(*rgb)
   puts "LED: #{(Time.now - start)*1000}ms"

   # Time fade:
   start = Time.now
   fade_leds
   puts "FADE: #{(Time.now - start)*1000}ms"
   ```

**Solutions:**

1. **Skip accel reads**
   ```ruby
   if $lc % 30 == 0  # Read every 30ms
     c = get_color
   end
   ```

2. **Skip LED updates**
   ```ruby
   if $lc % 2 == 0  # Show LED every 2ms
     $led.show_rgb(*rgb)
   end
   ```

3. **Reduce spread calculation**
   ```ruby
   # Simpler spread (only ±1):
   [
     [pos, 255, bri],
     [pos-1, 150, bri], [pos+1, 150, bri]
   ]
   # Skip ±2, ±3
   ```

---

## Debug Output Template

When troubleshooting, add this diagnostic block:

```ruby
if $lc % 500 == 0  # Every 500ms
  puts "=== LED DEBUG ==="#
  puts "Loop: #{$lc}"
  puts "Accel: #{$bx.inspect}" if $mpu
  puts "LED[0..4]: #{$co[0..4].map{|c| "0x#{c.to_s(16)}" }}"
  puts "LED[58..59]: #{$co[58..59].map{|c| "0x#{c.to_s(16)}" }}"
  puts "Color: 0x#{get_color.to_s(16)}" if $mpu
end
```

This provides key info for remote debugging.
