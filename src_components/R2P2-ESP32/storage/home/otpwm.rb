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
require 'uart'
require 'ws2812'
require 'gpio'
require 'irq'
require 'pwm'
require 'i2c'
require 'mpu6886'
require 'vl53l0x'
require 'iir_filter'

LED_COUNT = 30
LED_PIN = 19
SPEAKER_PIN = 33
DIST_MIN = 20
DIST_MAX = 170
FREQ_MIN = 262
FREQ_MAX = 1047
FREQ_RANGE = FREQ_MAX - FREQ_MIN

DEBUG = true
MUTE = false

KICK = 36
SNARE = 38
CLAP = 39
HI_HAT_C = 42
HI_HAT_O = 46
HI_TOM = 50
MID_TOM = 47
LOW_TOM = 41
CRASH = 49

GT = {36=>1, 38=>2, 39=>3, 49=>5, 50=>4, 47=>4, 41=>4, 42=>3, 46=>3}
HUES = [nil, 0, 128, 192, 64, 0]

drum_pattern = [
  KICK, HI_HAT_C, SNARE, HI_HAT_C,
  KICK, HI_HAT_C, SNARE, HI_HAT_O,
  KICK, MID_TOM, SNARE, HI_HAT_C,
  KICK, CLAP, SNARE, LOW_TOM
]

STEP_INTERVAL = 125

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

md_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 26, rxd_pin: 32)
sleep_ms(10)

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

md_uart.clear_rx_buffer
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
led_offset = 0
current_duty = 1
saturation = 200
brightness = 50
note_idx = 0
group_history = [1, 1, 1]
drum_saturation = 168
drum_brightness = 55

loop do
  IRQ.process
  tick_count += 1
  
  if tick_count % 1 == 0
    distance = distance_filter.filter(tof_sensor.read_distance)
    puts distance

    if distance > 0 && distance >= DIST_MIN && distance <= DIST_MAX
      base_freq = FREQ_MIN + (FREQ_MAX - distance) * FREQ_RANGE / (DIST_MAX - DIST_MIN)
      current_freq = base_freq.clamp(FREQ_MIN, FREQ_MAX)
      current_duty = BASE_DUTY
      
      note_idx = ((DIST_MAX - distance) * 24 / (DIST_MAX - DIST_MIN)).to_i.clamp(0, 24)
      led_offset = (led_offset + 1) % LED_COUNT
    else
      current_duty = 1
    end
  end
  
  if tick_count % 2 == 0
    accel_data = accel_sensor.acceleration
    
    if current_duty == 1
      speaker.duty(1)
    else
      vibrato = (accel_data[:y] * 20).to_i
      speaker.frequency((current_freq + vibrato).clamp(FREQ_MIN, FREQ_MAX))
      
      duty_delta = (accel_data[:x] * DUTY_DELTA_SCALE).to_i
      duty = (BASE_DUTY + duty_delta).clamp(DUTY_MIN, DUTY_MAX)
      speaker.duty(duty)
    end
    
    az = (accel_data[:z] * 100).to_i
    accel_mag = az.abs
    saturation = (accel_mag + 150).clamp(100, 255)
    brightness = (accel_mag / 2 + 30).clamp(20, 80)
  end
  
  if tick_count % STEP_INTERVAL == 0
    note = drum_pattern[drum_step % drum_pattern.size]
    md_uart.write((0x99).chr + note.chr + (0x60).chr)

    g = GT[note] || 4
    if g == 5
      led_strip.flash!(LED_COUNT)
    else
      group_history.shift
      group_history.push(g)
    end

    drum_step += 1
  end
  
  if current_duty == 1
    LED_COUNT.times { |i| led_colors[i] = 0 }
  else
    melody_hue = (note_idx * 384 / 24) % 384
    sb = (saturation << 8) | brightness
    melody_color = (melody_hue << 16) | sb
    
    10.times { |i|
      led_colors[(i * 3 + led_offset) % LED_COUNT] = melody_color
    }
  end
  
  drum_sb = (drum_saturation << 8) | drum_brightness
  group_history.each do |g|
    h = HUES[g] << 16 | drum_sb
    case g
    when 1
      5.times { |s|
        idx = (s * 6 + led_offset) % LED_COUNT
        led_colors[idx] = h if led_colors[idx] == 0
        led_colors[(idx + 1) % LED_COUNT] = h if led_colors[(idx + 1) % LED_COUNT] == 0
      }
    when 2
      5.times { |s|
        idx = (s * 6 + 3 + led_offset) % LED_COUNT
        led_colors[idx] = h if led_colors[idx] == 0
        led_colors[(idx + 1) % LED_COUNT] = h if led_colors[(idx + 1) % LED_COUNT] == 0
      }
    when 3
      6.times { |i|
        idx = (i * 5 + led_offset) % LED_COUNT
        led_colors[idx] = h if led_colors[idx] == 0
      }
    when 4
      3.times { |i|
        idx = (i * 10 + led_offset) % LED_COUNT
        led_colors[idx] = h if led_colors[idx] == 0
      }
    end
  end
  
  led_strip.show_hsb_hex(*led_colors)
  sleep_ms(1)
end

irq.unregister
