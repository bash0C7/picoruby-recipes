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

LED_COUNT = 30
LED_PIN = 22
SPEAKER_PIN = 32
DIST_MIN = 20
DIST_MAX = 170
FREQ_MIN = 262
FREQ_MAX = 1047
FREQ_RANGE = FREQ_MAX - FREQ_MIN

DEBUG = false
MUTE = true

FREQS = [262,277,294,311,330,349,370,392,415,440,466,494,523,554,587,622,659,698,740,784,831,880,932,988,1047]

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

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {led_strip: led_strip}) do |btn, ev, cap|
  cap[:led_strip].flash!(LED_COUNT)
end

tick_count = 0
current_freq = FREQ_MIN
led_offset = 0
current_duty = 1
saturation = 200
brightness = 50

loop do
  IRQ.process
  tick_count += 1
  
  if tick_count % 1 == 0
    distance = distance_filter.filter(tof_sensor.read_distance)
    puts distance

    if distance > 0 && distance >= DIST_MIN && distance <= DIST_MAX
      base_freq = FREQ_MIN + (FREQ_MAX - distance) * FREQ_RANGE / (DIST_MAX - DIST_MIN)
      base_freq = base_freq.clamp(FREQ_MIN, FREQ_MAX)
      current_freq = base_freq
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
      speaker.duty(current_duty)
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
  
  if current_duty == 1
    LED_COUNT.times { |i| led_colors[i] = 0 }
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