# PicoRuby Demo - Ultra Minimal
require 'ws2812'
require 'gpio'
require 'irq'
require 'uart'
require 'mpu6886'
require 'i2c'

puts "Demo Start"

# Hardware
led = WS2812.new(RMTDriver.new(22))
button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
pc_uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)
midi_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 26, rxd_pin: 32)
i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G

# State
state = {power: true}
brightness = Array.new(60, 0)
colors = Array.new(60, 0)

# Button IRQ
button.irq(GPIO::EDGE_FALL, debounce: 300, capture: state) do |btn, ev, cap|
  cap[:power] = !cap[:power]
  puts cap[:power] ? "ON" : "OFF"
end

# IMU calibration
puts "Calibrating..."
sx = sy = sz = 0
5.times do
  a = mpu.acceleration
  sx += (a[:x] * 100).to_i
  sy += (a[:y] * 100).to_i
  sz += (a[:z] * 100).to_i
  sleep_ms 100
end
base = [sx / 5, sy / 5, sz / 5]
puts "Base: #{base[0]}, #{base[1]}, #{base[2]}"

# MIDI init
sleep_ms(1000)
midi_uart.write((0xC0).chr + (83).chr)
sleep_ms(100)

# MIDI state
ms = 0
mstat = 0
mnote = 0

# Timing
lc = 0

puts "Ready"

loop do
  lc += 1
  
  # Button
  IRQ.process
  
  # IMU -> MIDI CC (every 5 loops)
  if lc % 5 == 0
    a = mpu.acceleration
    acc = [(a[:x] * 100).to_i, (a[:y] * 100).to_i, (a[:z] * 100).to_i]
    cc = [71, 74, 91]
    
    3.times do |k|
      d = acc[k] - base[k]
      v = ((d + 200) * 127 / 400).to_i
      v = 0 if v < 0
      v = 127 if v > 127
      midi_uart.write((0xB0).chr + cc[k].chr + v.chr)
    end
  end
  
  # PC UART -> MIDI
  data = pc_uart.read
  if data && data.length > 0
    midi_uart.write(data)
    
    # Parse MIDI (flat)
    i = 0
    while i < data.length
      b = data[i].ord
      
      if ms == 0 && (b == 0x90 || b == 0x80 || b == 0x99 || b == 0x89)
        mstat = b
        ms = 1
      elsif ms == 1
        mnote = b
        ms = 2
      elsif ms == 2
        # Note On
        if ((mstat == 0x90 || mstat == 0x99) && b > 0 && mnote >= 36 && mnote <= 84)
          pos = ((mnote - 36) % 12) * 5 + ((mnote - 36) / 12)
          if pos >= 0 && pos < 60
            br = b * 2
            br = 255 if br > 255
            brightness[pos] = br
            brightness[pos - 1] = br * 2 / 3 if pos > 0
            brightness[pos + 1] = br * 2 / 3 if pos < 59
            brightness[pos - 2] = br / 3 if pos > 1
            brightness[pos + 2] = br / 3 if pos < 58
          end
        end
        ms = 0
      end
      i += 1
    end
  end
  
  # Fade + Render (single loop)
  60.times do |j|
    # Fade
    if brightness[j] > 0
      brightness[j] = (brightness[j] * 97 / 100).to_i
      brightness[j] = 0 if brightness[j] < 5
    end
    
    # Render
    if state[:power] && brightness[j] > 0
      st = (j / 5) % 12
      # Dynamic color generation
      if st < 4
        r = 255
        g = st * 64
        b = 0
      elsif st < 6
        r = 255 - ((st - 4) * 128)
        g = 255
        b = 0
      elsif st < 9
        r = 0
        g = 255 - ((st - 6) * 85)
        b = (st - 6) * 85
      else
        r = (st - 9) * 128
        g = 0
        b = 255 - ((st - 9) * 85)
      end
      # Pack RGB into hex: 0xRRGGBB
      r = r * brightness[j] / 255
      g = g * brightness[j] / 255
      b = b * brightness[j] / 255
      colors[j] = (r << 16) | (g << 8) | b
    else
      colors[j] = 0
    end
  end
  
  led.show_hex(*colors)
  
  puts lc if lc % 200 == 0
  
  sleep_ms 20
end
