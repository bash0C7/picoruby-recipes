# LED & Distance
require 'ws2812'
require 'i2c'
require 'mpu6886'
require 'vl53l0x'

def chika(cnt, pin)
  led = WS2812.new(RMTDriver.new(pin))

  i2c = I2C.new(
    unit: :ESP32_I2C0,
    frequency: 100_000,
    sda_pin: 26,  # Grove SDA
    scl_pin: 32   # Grove SCL
  )
  sensor = VL53L0X.new(i2c)
  colors = Array.new(cnt) { [0, 0, 0] }
  distance = 0
  frame = 0

  loop do
    frame += 1
    
    # センサー読み取り頻度を下げる
    if frame % 5 == 0
      new_distance = sensor.read_distance
      puts new_distance
      distance = new_distance if new_distance > 0
    end
    
    # 距離に基づく色計算と輝度制御
    if distance <= 0
      # エラー時は微弱な白色
      base_r, base_g, base_b = 2, 2, 2
    else
      # 25cm刻みで色決定
      zone = (distance / 250).to_i  # 0, 1, 2, 3...
      
      case zone
      when 0  # 0-25cm: 緑
        base_r, base_g, base_b = 0, 51, 0
      when 1  # 25-50cm: 黄緑
        base_r, base_g, base_b = 25, 51, 0
      when 2  # 50-75cm: 黄
        base_r, base_g, base_b = 51, 51, 0
      when 3  # 75-100cm: オレンジ
        base_r, base_g, base_b = 51, 25, 0
      when 4  # 100-125cm: 赤
        base_r, base_g, base_b = 51, 0, 0
      when 5  # 125-150cm: 紫
        base_r, base_g, base_b = 51, 0, 25
      when 6  # 150-175cm: 青紫
        base_r, base_g, base_b = 25, 0, 51
      when 7  # 175-200cm: 青
        base_r, base_g, base_b = 0, 0, 51
      else    # 200cm超: 水色
        base_r, base_g, base_b = 0, 25, 51
      end
      
      # 25cm区間内での1cm刻み輝度調整
      cm_in_zone = distance % 250  # 区間内の位置(0-249)
      brightness_ratio = [1.0 - (cm_in_zone / 250.0) * 0.8, 0.2].max  # 100%→20%
    end
    
    # 全LEDに同じ色・輝度設定
    cnt.times do |i|
      if distance <= 0
        colors[i] = [base_r, base_g, base_b]
      else
        r = (base_r * brightness_ratio).to_i
        g = (base_g * brightness_ratio).to_i
        b = (base_b * brightness_ratio).to_i
        colors[i] = [r, g, b]
      end
    end
    
    led.show_rgb(*colors)
    
    sleep_ms(50)  # 間隔を長くしてCPU負荷軽減
  end
end

arg_cnt = ARGV[0] || 25
puts arg_cnt
arg_pin = ARGV[1] || 27
puts arg_pin
chika(arg_cnt.to_i, arg_pin.to_i)
