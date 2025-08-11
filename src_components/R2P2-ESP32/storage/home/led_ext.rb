# ATOM Matrix ext grove LED
# Built-in WS2812 LEDs connected to GPIO 26(ext grove)
# Using picoruby-ws2812 gem

require 'ws2812'
require 'mpu6886'

led_pin = 26
led_count = 15

def chika(cnt, pin)
  led = WS2812.new(RMTDriver.new(pin))
  mpu = MPU6886.new(I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21))
  mpu.accel_range = MPU6886::ACCEL_RANGE_4G
  
  colors = Array.new(cnt) { [0, 0, 0] }
  
  off = 0
  frame = 0
  spd = 0
  str = 50
  a = { x: 0.0, y: 0.0, z: 0.0 }  # 初期値設定
  
  # 整数演算用の定数 (10000倍スケール)
  pi_x10000 = 31416        # π * 10000
  pi2_x10000 = 62832       # 2π * 10000
  step_x10000 = 3000       # 0.3 * 10000
  
  loop do
    frame += 1
    if frame % 5 == 0  # センサー読み取り頻度を下げる
      a = mpu.acceleration
      spd = (a[:x] * 100).to_i
      str = (a[:y].abs * 100).to_i
      str = str > 255 ? 255 : str
    end
    
    cnt.times do |i|
      # 整数演算で三角波近似
      pos = (off + i * step_x10000) % pi2_x10000
      
      if pos < pi_x10000
        val = pos - (pi_x10000 / 2)  # -π/2からπ/2
      else
        val = (pi_x10000 * 3 / 2) - pos  # 逆向き
      end
      
      # 正規化 (-π/2 to π/2 → -15708 to 15708)
      val = val > 15708 ? 15708 : (val < -15708 ? -15708 : val)
      
      # X軸の値で色を決定（左右の動き）
      x_val = (a[:x] * 1000).to_i  # X軸値を拡大
      
      # 加速度の大きさで輝度調整
      accel_magnitude = (a[:x].abs + a[:y].abs + a[:z].abs) * 1000
      if accel_magnitude > 2000  # 極めて高い加速度
        max_brightness = 128  # 255 * 0.5
      else
        max_brightness = 51   # 255 * 0.2
      end
      
      if x_val < -200
        # 左に傾ける：赤
        r = max_brightness
        g = 0
        b = 0
      elsif x_val > 200
        # 右に傾ける：青
        r = 0
        g = 0
        b = max_brightness
      else
        # 中央：緑
        r = 0
        g = max_brightness
        b = 0
      end
      
      colors[i] = [r, g, b]
    end
    
    led.show_rgb(*colors)
    off = (off + 2000 + spd * 10) % pi2_x10000
    
    sleep_ms(50)  # 間隔を長くしてCPU負荷軽減
  end
end

chika(led_count, led_pin)
