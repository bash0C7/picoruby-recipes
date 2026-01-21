class DPWM
  def initialize(pin, param = {})
#    puts "new #{pin}, #{param.to_s}"
  end

  def frequency(f)
#    puts "frequency #{f}"
  end

  def duty(d)
#    puts "duty #{d}"
  end
end

require 'ws2812'
require 'gpio'
require 'irq'
require 'pwm'
require 'i2c'
require 'mpu6886'
require 'vl53l0x'
require 'iir_filter'
require 'uart'

LED_COUNT = 30
LED_PIN = 22
SPEAKER_PIN = 33
DIST_MIN = 20
DIST_MAX = 300
FREQ_MIN = 262
FREQ_MAX = 1047
FREQ_RANGE = FREQ_MAX - FREQ_MIN
NOTE_BASE = 48
NOTE_RANGE = 24
DIST_RANGE = DIST_MAX - DIST_MIN

DEBUG = false
MUTE = false

if DEBUG
  BASE_DUTY = 15
  DUTY_MIN = 10
  DUTY_MAX = 25
  DUTY_DELTA_SCALE = 7
else
  BASE_DUTY = 35
  DUTY_MIN = 20
  DUTY_MAX = 50
  DUTY_DELTA_SCALE = 15
end

KICK = 36
SNARE = 38
CLAP = 39
HI_HAT_CLOSE = 42
HI_HAT_OPEN = 46
HIGH_TOM = 50
MID_TOM = 47
LOW_TOM = 41
CRASH = 49

DRUM_PATTERN = [
  KICK, HI_HAT_CLOSE, SNARE, HI_HAT_CLOSE,
  KICK, HI_HAT_CLOSE, SNARE, HI_HAT_OPEN,
  KICK, MID_TOM, SNARE, HI_HAT_CLOSE,
  KICK, CLAP, SNARE, LOW_TOM
]

STEP_INTERVAL = 3

GT = {36=>1, 38=>2, 39=>3, 49=>5, 52=>5}
HUES_DRUM = [nil, 0, 128, 192, 64, 0]

speaker = if MUTE
  DPWM.new(SPEAKER_PIN, frequency: 262, duty: 1)
else
  PWM.new(SPEAKER_PIN, frequency: 262, duty: 1)
end

button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
led_strip = WS2812.new(RMTDriver.new(LED_PIN))
led_colors = Array.new(LED_COUNT, 0)

i2c_bus = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
sleep_ms(100)

accel_sensor = MPU6886.new(i2c_bus)
sleep_ms(100)
accel_sensor.accel_range = MPU6886::ACCEL_RANGE_2G
sleep_ms(100)

tof_sensor = VL53L0X.new(i2c_bus)
sleep_ms(100)

distance_filter = IIRFilter.new

md_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 26, rxd_pin: 32)
sleep_ms(10)
md_uart.clear_rx_buffer

md_uart.write((0xC0).chr + (80).chr)
sleep_ms(10)
md_uart.write((0xB0).chr + (65).chr + (127).chr)
sleep_ms(10)
md_uart.write((0xB0).chr + (5).chr + (80).chr)
sleep_ms(10)
md_uart.write((0xB0).chr + (73).chr + (100).chr)
sleep_ms(10)
md_uart.write((0xB0).chr + (72).chr + (80).chr)
sleep_ms(10)

md_uart.write((0xB9).chr + (32).chr + (16).chr)
sleep_ms(10)
md_uart.write((0xC9).chr + (0).chr)
sleep_ms(10)

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {md_uart: md_uart, led_strip: led_strip}) do |btn, ev, cap|
  cap[:md_uart].write((0x99).chr + CRASH.chr + (0x7F).chr)
  cap[:led_strip].flash!(LED_COUNT)
end

tick_count = 0
drum_step = 0
current_freq = FREQ_MIN
current_note = 0
note_idx = 0
led_offset = 0
current_duty = 1
saturation = 200
brightness = 50
group_history = [1, 1, 1]

loop do
  IRQ.process
  tick_count += 1
  
  if tick_count % STEP_INTERVAL == 0
    note = DRUM_PATTERN[drum_step % DRUM_PATTERN.size]
    md_uart.write((0x99).chr + note.chr + (0x60).chr)
    
    g = GT[note] || 4
    if g != 5
      group_history.shift
      group_history.push(g)
    end
    drum_step += 1
  end
  
  if tick_count % 1 == 0
    distance = distance_filter.filter(tof_sensor.read_distance)

    if distance > 0 && distance >= DIST_MIN && distance <= DIST_MAX
      base_freq = FREQ_MIN + (FREQ_MAX - distance) * FREQ_RANGE / DIST_RANGE
      base_freq = base_freq.clamp(FREQ_MIN, FREQ_MAX)
      current_freq = base_freq
      current_duty = BASE_DUTY
      
      semitone_value = (DIST_MAX - distance) * NOTE_RANGE * 1000 / DIST_RANGE
      base_note = NOTE_BASE + (semitone_value / 1000)
      pitch_fraction = semitone_value % 1000
      
      if base_note != current_note
        if current_note != 0
          md_uart.write((0x80).chr + current_note.chr + (0x00).chr)
        end
        md_uart.write((0x90).chr + base_note.chr + (0x7F).chr)
        current_note = base_note
      end
      
      note_idx = semitone_value / 1000
      led_offset = (led_offset + 1) % LED_COUNT
    else
      if current_note != 0
        md_uart.write((0x80).chr + current_note.chr + (0x00).chr)
        current_note = 0
      end
      current_duty = 1
    end
  end
  
  if tick_count % 2 == 0
    accel_data = accel_sensor.acceleration
    
    if current_duty == 1
      speaker.duty(current_duty)
    else
      vibrato = (accel_data[:y] * 20).to_i
      speaker.frequency((current_freq + vibrato).clamp(FREQ_MIN, FREQ_MAX))
      
      duty_delta = (accel_data[:x] * DUTY_DELTA_SCALE).to_i
      duty = (BASE_DUTY + duty_delta).clamp(DUTY_MIN, DUTY_MAX)
      speaker.duty(duty)
    end
    
    if current_note != 0
      distance = distance_filter.filter(tof_sensor.read_distance)
      if distance > 0 && distance >= DIST_MIN && distance <= DIST_MAX
        semitone_value = (DIST_MAX - distance) * NOTE_RANGE * 1000 / DIST_RANGE
        pitch_fraction = semitone_value % 1000
        
        pitch_bend_offset = pitch_fraction * 4096 / 1000
        vibrato_offset = (accel_data[:y] * 200).to_i
        total_bend = (8192 + pitch_bend_offset + vibrato_offset).clamp(0, 16383)
        
        bend_lsb = total_bend & 0x7F
        bend_msb = (total_bend >> 7) & 0x7F
        md_uart.write((0xE0).chr + bend_lsb.chr + bend_msb.chr)
      end
      
      mod_value = ((accel_data[:x] * 63) + 64).to_i.clamp(0, 127)
      md_uart.write((0xB0).chr + (1).chr + mod_value.chr)
      
      cutoff_value = ((accel_data[:z] * 63) + 64).to_i.clamp(0, 127)
      md_uart.write((0xB0).chr + (74).chr + cutoff_value.chr)
    end
    
    az = (accel_data[:z] * 100).to_i
    accel_mag = az.abs
    saturation = (accel_mag + 150).clamp(100, 255)
    brightness = (accel_mag / 2 + 30).clamp(20, 80)
  end
  
  if current_duty == 1
    sb = (saturation << 8) | brightness
    group_history.each do |g|
      h = HUES_DRUM[g] << 16 | sb
      case g
      when 1
        10.times { |s|
          led_colors[(s * 3) % LED_COUNT] = h
        }
      when 2
        10.times { |s|
          led_colors[(s * 3 + 1) % LED_COUNT] = h
        }
      when 3
        10.times { |s|
          led_colors[(s * 3 + 2) % LED_COUNT] = h
        }
      when 4
        6.times { |i| led_colors[(i * 5) % LED_COUNT] = h }
      end
    end
  else
    hue = (note_idx * 384 / 24) % 384
    sb = (saturation << 8) | brightness
    color = (hue << 16) | sb
    
    10.times { |i|
      led_colors[(i * 3 + led_offset) % LED_COUNT] = color
    }
  end
  
  led_strip.show_hsb_hex(*led_colors)
  sleep_ms(1)
end

irq.unregister