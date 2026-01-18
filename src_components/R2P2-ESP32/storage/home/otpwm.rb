require 'ws2812'
require 'gpio'
require 'irq'
require 'pwm'
require 'i2c'
require 'mpu6886'
require 'vl53l0x'

# 定数定義
LED_COUNT = 30
LED_PIN = 22
SPEAKER_PIN = 32
DIST_MIN = 50
DIST_MAX = 500
NOTE_COUNT = 25

# 周波数テーブル(C4〜C6)
FREQS = [262,277,294,311,330,349,370,392,415,440,466,494,523,554,587,622,659,698,740,784,831,880,932,988,1047]

# ハードウェア初期化
speaker = PWM.new(SPEAKER_PIN, frequency: 440, duty: 0)
button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
led_strip = WS2812.new(RMTDriver.new(LED_PIN))
led_colors = Array.new(LED_COUNT, 0)

# I2C・センサー初期化
i2c_bus = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
sleep_ms(100)

accel_sensor = MPU6886.new(i2c_bus)
sleep_ms(100)
accel_sensor.accel_range = MPU6886::ACCEL_RANGE_2G
sleep_ms(100)

tof_sensor = VL53L0X.new(i2c_bus)
sleep_ms(100)

unless tof_sensor.ready?
  puts "VL53L0X init failed!"
end

# IRQ設定(ボタンでフラッシュ)
irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {led_strip: led_strip}) do |btn, ev, cap|
  cap[:led_strip].flash!(LED_COUNT)
end

# 状態変数
tick_count = 0
current_note_idx = -1
led_offset = 0
base_duty = 35
saturation = 200
brightness = 50

puts "Otamatone PWM mode start!"

loop do
  IRQ.process
  tick_count += 1
  
  # 距離測定→音階決定(20msごと)
  if tick_count % 20 == 0
    distance = tof_sensor.read_distance
    
    if distance > 0 && distance >= DIST_MIN && distance <= DIST_MAX
      # 距離を音階インデックスに変換
      note_idx = ((DIST_MAX - distance) * (NOTE_COUNT - 1) / (DIST_MAX - DIST_MIN)).to_i
      note_idx = note_idx.clamp(0, NOTE_COUNT - 1)
      
      if note_idx != current_note_idx
        current_note_idx = note_idx
        freq = FREQS[note_idx]
        speaker.frequency(freq)
        
        # LED色更新
        hue = (note_idx * 384 / NOTE_COUNT) % 384
        led_offset = (led_offset + 3) % LED_COUNT
      end
    else
      # 範囲外→消音
      if current_note_idx >= 0
        speaker.duty(0)
        current_note_idx = -1
      end
    end
  end
  
  # 加速度測定→音色変化(50msごと)
  if tick_count % 50 == 0 && current_note_idx >= 0
    accel_data = accel_sensor.acceleration
    
    # X軸でduty比変化(20%〜50%)
    duty_delta = (accel_data[:x] * 15).to_i
    duty = (base_duty + duty_delta).clamp(20, 50)
    speaker.duty(duty)
    
    # Y/Z軸で彩度・輝度変化
    ay = (accel_data[:y] * 100).to_i
    az = (accel_data[:z] * 100).to_i
    accel_mag = ay.abs + az.abs
    saturation = (accel_mag + 150).clamp(100, 255)
    brightness = (accel_mag / 2 + 30).clamp(20, 80)
  end
  
  # LED更新
  if current_note_idx >= 0
    hue = (current_note_idx * 384 / NOTE_COUNT) % 384
    sb = (saturation << 8) | brightness
    color = (hue << 16) | sb
    
    10.times { |i|
      led_colors[(i * 3 + led_offset) % LED_COUNT] = color
    }
  else
    LED_COUNT.times { |i| led_colors[i] = 0 }
  end
  
  led_strip.show_hsb_hex(*led_colors)
  sleep_ms(1)
end

irq.unregister
