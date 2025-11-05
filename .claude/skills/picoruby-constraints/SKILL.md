---
name: picoruby-constraints
description: PicoRuby/mruby constraints, memory limitations (520KB), stdlib restrictions, and embedded coding practices. Use when writing .rb files, optimizing memory, handling embedded constraints, or comparing PicoRuby vs CRuby features.
---

# PicoRuby Development Constraints & Best Practices

## What is PicoRuby vs CRuby?

| Aspect | CRuby (Ruby) | PicoRuby (mruby/c) |
|--------|-------------|------------------|
| **Full name** | Ruby (standard) | mruby/c subset |
| **Runtime** | Full VM | Lightweight VM for embedded |
| **Gems/Bundler** | ✅ Full RubyGems support | ❌ No gems, no bundler |
| **Standard Library** | Comprehensive | Limited stdlib only |
| **Use case** | General-purpose development | Embedded systems, microcontrollers |
| **Memory footprint** | High | Minimal |
| **Execution speed** | Slower | Much faster |
| **Platform** | Linux, macOS, Windows, etc. | Arduino, ESP32, embedded devices |

**CRITICAL**: When you edit `.rb` files in this project, they run on **PicoRuby/mruby**, NOT CRuby. Never use CRuby-only features like bundler, gems, or complex stdlib imports.

---

## Memory Constraints

**ESP32 Hardware Limitation**:
- **Total RAM**: 520KB (excluding system usage)
- **Available for application**: Limited
- **Strategy**: Pre-allocate, avoid dynamic allocation

**Memory Optimization Rules**:
1. ✅ **Pre-allocate arrays** with fixed sizes
   ```ruby
   # Good: Pre-allocated array (memory reserved upfront)
   leds = Array.new(60, 0)

   # Avoid: Dynamic array growth
   leds = []
   60.times { |i| leds << 0 }  # Memory fragmentation risk
   ```

2. ✅ **Use simple data structures**
   ```ruby
   # Good: Flat array/hash
   pad_history = [0, 0, 0, 0, 0]

   # Avoid: Nested classes, complex objects
   class PadState
     def initialize
       @history = []  # Not great for embedded
     end
   end
   ```

3. ✅ **Reuse variables** (minimize allocations)
   ```ruby
   # Good: Reuse buffer
   r, g, b = 0, 0, 0
   60.times { |i| r, g, b = get_color(i); set_led(i, r, g, b) }

   # Avoid: Creating new objects in loop
   60.times { |i| color = Color.new(r, g, b); set_led(i, color) }
   ```

4. ✅ **Minimize string allocations**
   ```ruby
   # Good: Single string
   msg = "status: ok"

   # Avoid: String concatenation in loops
   msg = ""
   10.times { |i| msg += "val: #{i}\n" }  # Creates 10 strings
   ```

---

## Embedded System Coding Rules

### Shallow Nesting (Memory Critical)
- ✅ **Maximum nesting depth**: 2-3 levels
- ✅ **Keep functions linear and simple**
- ❌ Avoid deeply nested control flow

```ruby
# Good: Shallow, linear
def update_leds(pads)
  pads.each { |pad| set_color(pad) }
end

# Avoid: Deep nesting (wastes stack memory)
def update_leds(pads)
  pads.each do |pad|
    if pad > 0
      if can_update?
        if should_glow?
          set_color(pad)  # 4 levels deep
        end
      end
    end
  end
end
```

### Exception Handling
- ✅ Use sparingly (exception objects consume memory)
- ✅ Validate inputs upfront instead
- ❌ Avoid nested begin/rescue blocks

```ruby
# Good: Input validation
def set_led_safe(index, color)
  return if index < 0 || index >= 60
  set_led(index, color)
end

# Avoid: Exception-based flow control
def set_led_safe(index, color)
  begin
    set_led(index, color)
  rescue
    puts "Invalid index"
  end
end
```

### No Complex Class Hierarchies
- ✅ Flat module/function structure
- ✅ Simple data classes (mostly fields)
- ❌ Avoid inheritance chains, abstract classes, mixins

```ruby
# Good: Simple functions and flat data
def pad_hit(pad_id, velocity)
  # ... logic here
end

class PadState
  attr_accessor :id, :velocity, :timestamp
end

# Avoid: Inheritance & method overrides
class Instrument
  def play; end
end

class Drum < Instrument
  def play; end
end
```

---

## Coding Style for .rb Files

### Comments: Japanese, Noun-Ending Style (体言止め)
Write comments ending in nouns, not verbs. This creates a compressed, declarative style suitable for embedded code.

```ruby
# Good: Noun-ending (体言止め)
# PAD履歴管理
def add_to_history(pad_id)
  @history.shift
  @history.push(pad_id)
  # 最新5PADの追跡
end

# Avoid: Verb-ending
# Add the PAD to history
def add_to_history(pad_id)
  @history.shift
  @history.push(pad_id)
  # Track the 5 most recent PADs
end
```

### Variable Naming
- ✅ Short, clear names (memory saves characters)
- ✅ Japanese is OK for domain concepts
- ✅ English for standard concepts

```ruby
# Good:
h = [0, 0, 0, 0, 0]  # 履歴
pad_id = 12
v = velocity  # Velocity (speed of hit)

# Avoid:
pad_history_buffer = []  # Too verbose
previous_pad_indices = []
```

### Loops: Prefer Linear Iteration
- ✅ `.each`, `.times` for simple iteration
- ❌ Avoid `.map`, `.select`, `.reduce` (allocate new arrays)

```ruby
# Good: .each (no allocation)
leds.each { |led| set_led(led) }

# Avoid: .map (allocates new array)
new_leds = leds.map { |led| process(led) }
```

---

## PicoRuby Standard Library (Allowed)

PicoRuby has a minimal stdlib. **Only use these features**:

### Core Classes
- `String`, `Array`, `Hash`
- `Integer`, `Float`
- `Range`
- `Proc`, `Lambda`
- `File` (limited)
- `Time` (limited)
- `Random`

### Built-in Modules
- `Enumerable` (`.each`, `.times`, etc.)
- `Comparable` (`<`, `>`, `==`)
- `Math` (`Math.sin`, `Math.cos`, `Math.sqrt`)

### What's NOT Available
- ❌ `require`, `require_relative` (no external gems)
- ❌ Complex IO operations
- ❌ Networking (no TCP/UDP directly)
- ❌ Advanced meta-programming
- ❌ Threads (minimal concurrency)
- ❌ `Struct`, `OpenStruct`
- ❌ Regex (limited support)

---

## Hardware-Specific PicoRuby Classes

The R2P2-ESP32 runtime adds these classes:

### GPIO Control
```ruby
GPIO.set_mode(pin, :output)   # Configure pin
GPIO.write(pin, 0)             # Set low
GPIO.write(pin, 1)             # Set high
GPIO.read(pin)                 # Read state
```

### UART Communication
```ruby
uart = UART.new(0, 115200)     # UART 0, 115200 bps
uart.puts("message")            # Send string
data = uart.read(1)             # Read 1 byte
```

### I2C Communication
```ruby
i2c = I2C.new(0, 21, 22)       # I2C 0, SDA=21, SCL=22
i2c.write(0x68, [0x3B])        # Write to address 0x68
data = i2c.read(0x68, 6)       # Read 6 bytes from 0x68
```

### Timers
```ruby
now = Time.now.to_i            # Current time (seconds)
sleep(0.1)                      # Sleep 100ms
```

### PWM (if available)
```ruby
PWM.set_duty(pin, 128, 255)    # Set 50% duty cycle
```

---

## Common Pitfalls to Avoid

| Problem | Why Bad | Solution |
|---------|---------|----------|
| Global variables | Unpredictable state, hard to debug | Use local/parameter passing |
| String concatenation in loops | O(n²) memory allocations | Pre-allocate or use arrays |
| Dynamic array growth | Memory fragmentation | Pre-allocate with `Array.new(size)` |
| Deep function call stacks | Stack overflow risk | Keep functions shallow |
| Complex error handling | Exception objects consume memory | Validate inputs upfront |
| Inheritance chains | Extra memory per instance | Use flat composition |
| Float arithmetic | Precision issues in embedded systems | Use integers when possible |
| Blocking I/O in loops | Can freeze the system | Use non-blocking or timeouts |

---

## Performance Tips for Embedded Systems

1. **Loop optimization**: Call expensive functions outside loops
   ```ruby
   # Good
   max_val = 255
   leds.each { |led| set_led(led, max_val) }

   # Bad: calculate_max() called 60 times
   leds.each { |led| set_led(led, calculate_max()) }
   ```

2. **Minimize method calls**: Direct array access is faster
   ```ruby
   # Good: Direct access
   @history[0] = pad_id

   # Slightly slower: Method call
   set_history_item(0, pad_id)
   ```

3. **Use bit operations** for flags and masks
   ```ruby
   # Good: Bitwise (1 byte)
   active_pads = 0x0F  # First 4 pads

   # Less efficient: Array of booleans
   active_pads = [true, true, true, true, false, ...]
   ```

---

## Memory Audit Checklist

Before deploying .rb code:

- [ ] No dynamic array growth (use `Array.new(size)`)
- [ ] No string concatenation in loops
- [ ] Functions stay 2-3 nesting levels max
- [ ] No unused global variables
- [ ] All constants pre-defined (not computed at runtime)
- [ ] Reusing local variables where possible
- [ ] No memory leaks from circular references
- [ ] Hardware resources freed properly (UART.close, etc.)

---

## Related Skills & Resources

- **atom-matrix-hardware**: GPIO pin assignments, MPU6886 sensor protocol, WS2812 LED control
- **finger-drum**: Full application example using PicoRuby
- **led-visualization**: Memory-optimized LED visualization with < 300 byte footprint

---

## Version History

- v1.0 (2025-11-05): Initial documentation based on CLAUDE.md refactoring
