# LED Visual Pattern Gallery

Collection of visual effects achievable with LED parameter combinations.

## Pattern 1: Classic Flash-Light (Default)

**Configuration:**
```ruby
bri = (vel * 2).clamp(0, 255)
saturation = [255, 179, 102, 51]
fade_interval = 15 loops (~15ms)
fade_rate = 3%
spread = ±3
```

**Timeline:**
```
0ms:    [■▓▒░........................▒▓■▓▒............]
        Center: full brightness, edges white
        Secondary position glows independently

15ms:   [▓▒░░........................░▒▓▒░............]
        3% decay applied globally

30ms:   [▒░░........................░░▓▒░............]
        Both points fade in parallel

100ms:  [░░░........................░░░░░............]
        Very dim, almost invisible
```

**Visual Effect:** Classic stage flash-light, bright center dimming to ambient light.

**Best for:** High-energy performances, clear beat visualization.

---

## Pattern 2: Soft Sustained Glow

**Configuration:**
```ruby
bri = vel
saturation = [255, 190, 130, 70]
fade_interval = 30 loops (~30ms)
fade_rate = 2%
spread = ±4
```

**Timeline:**
```
0ms:    [■▓▒▒░...................░▒▒▓■▓▒▒░............]
        Wider spread than default
        Lower center intensity

30ms:   [▓▒▒░░...................░▒▒▓▓▒▒░............]
        2% decay every 30ms = longer persistence

100ms:  [▓▒▒▒▒...................▒▒▒▓▓▒▒▒............]
        Still visible after 100ms
        Gradual fading (smoother curve)

300ms:  [░░░░░...................░░░░░░░░░............]
        Taken ~3 seconds to fully fade
```

**Visual Effect:** Gentle, sustained glow. Ambient energy without harshness.

**Best for:** Jazz performances, ballads, smooth electronic music.

---

## Pattern 3: Sharp Impact Punch

**Configuration:**
```ruby
bri = (vel * 3.5).clamp(0, 255)
saturation = [255, 100, 30, 5]
fade_interval = 12 loops (~12ms)
fade_rate = 5%
spread = ±2
```

**Timeline:**
```
0ms:    [■▒░........................▒░............]
        Concentrated bright center
        Rapid white convergence at ±1

12ms:   [▓░░........................░░............]
        Fast decay

24ms:   [░░░........................░░............]
        Nearly gone

36ms:   [disappear]
        Total lifetime ~35ms (punchy!)
```

**Visual Effect:** Sharp, percussive hit. Reminiscent of electronic synth drums.

**Best for:** EDM, tech house, high-impact drum patterns.

---

## Pattern 4: Color Sweep with Acceleration

**Configuration:**
```ruby
bri = (vel * 2).clamp(0, 255)
saturation = [255, 180, 110, 60]
fade_interval = 20 loops (~20ms)
fade_rate = 2%
spread = ±3
accel_clamp = ±150  # Amplified tilt response
```

**Timeline (Performer tilts during hit):**
```
0ms: Neutral (White center)
  [■▓▒░]

Time +10ms: Performer tilts forward (Y+)
  Color changes to Green
  [■▓▒░] → Green tone

Time +20ms: Tilts right (X+)
  Color shifts to Cyan
  [▓▒░░] → Cyan tone

Time +30ms: Continues rotation (Z+)
  Color shifts to Blue
  [░░░░] → Blue tone

Time +50ms: Returns to neutral
  Color back to White
  [░░░░] → White tone, nearly invisible
```

**Visual Effect:** Dynamic rainbow effect tracking performer motion.

**Best for:** Interactive performances, gesture-based expression.

---

## Pattern 5: Polyphonic Overlap

**Configuration:**
```ruby
bri = (vel * 2).clamp(0, 255)
saturation = [255, 179, 102, 51]
fade_interval = 15 loops
fade_rate = 3%
spread = ±3
or_accumulation = true (default)
```

**Timeline (Rapid Kick-Tom-Snare-HH sequence):**
```
Time 0ms:   Kick (36, pos1=0)
  [■▓▒░................................................................]

Time +3ms:  Tom (45, pos1=10)
  [■▓▒░.........■▓▒░.............................................]

Time +5ms:  Snare (38, pos1=1)
  [■■▓▒░▒░.....■▓▒░.............................................]
    ↑↑ Overlap: brighter due to OR!

Time +8ms:  HH (42, pos1=2)
  [■■■▓▒░▒░...■▓▒░.............................................]
    ↑↑↑ Triple overlap: very bright!

Time +15ms: First fade
  [▓▓▓▒░░▒░...▓▒░░.............................................]
  All decay 3% together

Time +50ms: Sequence ends
  [░░░░░░░░...░░░░.............................................]
  Clean darkness, ready for next sequence
```

**Visual Effect:** Polyphonic visual harmony. Overlapping flashes = combined visual energy.

**Best for:** Groove-based patterns, polyrhythmic structures.

---

## Pattern 6: Monochrome Minimalist

**Configuration:**
```ruby
bri = (vel * 2).clamp(0, 255)
saturation = [255, 255, 255, 255]  # NO COLOR FADE
fade_interval = 15 loops
fade_rate = 3%
spread = ±2  # Tighter
accel_sensor = disabled ($mpu = nil)
```

**Timeline:**
```
0ms:    [■▓▒........................▒▓■▓▒............]
        Pure white, no tint regardless of tilt

15ms:   [▓▒░........................░▒▓▒░............]
        Same white, just dimmer

30ms:   [░░░........................░░░░░............]
        Very dim white

100ms:  [disappear]
```

**Visual Effect:** Pure monochrome pulsing. Clean, minimalist aesthetic.

**Best for:** Installation art, pure rhythm visualization, debugging.

---

## Pattern 7: Chaotic Spread (Full Range)

**Configuration:**
```ruby
bri = (vel * 2).clamp(0, 255)
saturation = [255, 160, 90, 30]
fade_interval = 8 loops (~8ms, very fast)
fade_rate = 6%
spread = ±5  # Very wide
pseudo_random = ($lc * 13 + note * 5) % 60  # Maximum variety
collision_offset = 30 (large)
```

**Timeline:**
```
0ms:    [■▓▒░░░........................░░░▒▓■▓▒░░░]
        Dual points very spread out
        ±5 coverage

8ms:    [▓▒░░░░........................░░░░▒▓▒░░░]
        Fast decay

16ms:   [░░░░░░........................░░░░░░░░░░░]
        Nearly gone

Notes:
- High entropy distribution
- Every 8ms pulse feels chaotic
- Secondary point appears very different each time
```

**Visual Effect:** Chaotic energy, visual surprise. "Crazy drummer" vibe.

**Best for:** Avant-garde performances, controlled chaos.

---

## Pattern 8: Strobe Effect

**Configuration:**
```ruby
bri = (vel * 2.5).clamp(0, 255)
saturation = [255, 255, 255, 255]  # Saturated
fade_interval = 4 loops (~4ms, very fast strobe)
fade_rate = 10%  # Aggressive decay
spread = ±1  # Tight
```

**Timeline:**
```
0ms:    [■▒.........................▒■▒..]
        BRIGHT FLASH

4ms:    [░░........................░░░..]
        Off

8ms:    [■▒.........................▒■▒..]
        BRIGHT FLASH again

Result: Alternating bright/dark every 4ms = 125 Hz strobe effect
```

**Visual Effect:** Stroboscopic pulsing. Hypnotic, rhythmic effect.

**Best for:** Rave/techno performances, creating temporal disorientation.

---

## Pattern 9: Trailing Comet

**Configuration:**
```ruby
bri = (vel * 1.8).clamp(0, 255)
saturation = [255, 200, 120, 60]
fade_interval = 20 loops
fade_rate = 1%  # Very slow decay
spread = ±4
# Special: pos2 calculated with time offset
pos2 = ($lc * 7 + note * 3 + (vel / 10)) % 60  # Velocity-dependent offset
```

**Timeline:**
```
0ms:    [■▓▒░▒........................▒▓▒░]
        Primary and secondary both bright

20ms:   [■▓▒░░........................░▓▒░]
        1% decay = very slow fade

40ms:   [▓▒░░░........................░▓▒░]
        Still very visible

100ms:  [▒░░░░........................░▒░░]
        Long trail visible

300ms:  [░░░░░........................░░░░]
        Persists longest
```

**Visual Effect:** Comet-like trails. Velocity creates visual momentum.

**Best for:** Cinematic performances, visual storytelling.

---

## Pattern 10: Mirror Symmetry

**Configuration:**
```ruby
bri = (vel * 2).clamp(0, 255)
saturation = [255, 179, 102, 51]
fade_interval = 15 loops
fade_rate = 3%
spread = ±3
# Special: pos2 calculated as mirror
pos1 = DRUM_LED[note]
pos2 = 59 - pos1  # Mirror opposite side
```

**Timeline:**
```
0ms:    [■▓▒░........................░▒▓■]
        Both positions equidistant from center (29.5)

15ms:   [▓▒░░........................░░▒▓]
        Symmetric fade

30ms:   [░░░░........................░░░░]
        Still symmetric

Effect: Perfect left-right mirror
```

**Visual Effect:** Symmetric visual balance. Meditative, harmonious.

**Best for:** Ambient performances, balanced compositions.

---

## Mixing Patterns

### Fast Kick + Slow Hi-Hat
```ruby
if note == 36  # Kick
  bri = (vel * 3).clamp(0, 255)
  fade_interval = 10 loops  # Fast
elsif note == 42  # Hi-Hat
  bri = vel
  fade_interval = 40 loops  # Slow
end
# Result: Kick pops quickly, HH sustains
```

### Color by Drum Type
```ruby
accel_clamp = if note < 45
  -100, 100  # Drums: amplified response
else
  -200, 200  # Cymbals: subtle response
end
```

## Parameter Lookup

To achieve specific visual goals, adjust:

| Goal | Change |
|------|--------|
| Faster disappear | Reduce fade_interval (15→8) |
| Longer glow | Increase fade_interval (15→30) |
| Wider spread | Increase spread (±3→±5) |
| Tighter focus | Decrease spread (±3→±1) |
| More saturated | Increase saturation array values |
| More white edges | Decrease saturation array values |
| Brighter | Increase bri scaling (×2→×3) |
| Softer | Decrease bri scaling (×2→×1) |
| More colorful | Reduce accel_clamp (±200→±150) |
| Less colorful | Increase accel_clamp (±200→±300) |
