require 'ws2812'
require 'i2c'
require 'mpu6886'

class NagaraLed
  # LED (GPIO 32 for ATOM Matrix Grove)  (GPIO 27 for ATOM Matrix Internal)

  def chika(cnt, pin = 32)
    led = WS2812.new(RMTDriver.new(pin))
    mpu = MPU6886.new(I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21))
    mpu.accel_range = MPU6886::ACCEL_RANGE_4G
    
    colors = Array.new(cnt) { [0, 0, 0] }
    
    off = 0
    frame = 0
    spd = 0
    str = 50
    
    # 整数演算用の定数 (10000倍スケール)
    pi_x10000 = 31416        # π * 10000
    pi2_x10000 = 62832       # 2π * 10000
    step_x10000 = 3000       # 0.3 * 10000
    
    loop do
      frame += 1
      if frame % 10 == 0  # センサー読み取り頻度を下げる
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
        
        # RGB計算 (整数のみ)
        r_base = (val + 15708) * str / 31416
        r = r_base > 255 ? 255 : (r_base < 0 ? 0 : r_base)
        
        g_base = (-val + 15708) * str / 31416
        g = g_base > 255 ? 255 : (g_base < 0 ? 0 : g_base)
        
        b_base = 150 + val / 314
        b = b_base > 255 ? 255 : (b_base < 0 ? 0 : b_base)
        
        colors[i] = [r, g, b]
      end
      
      led.show_rgb(*colors)
      off = (off + 2000 + spd * 10) % pi2_x10000
      
      sleep(0.1)  # 間隔を長くしてCPU負荷軽減
    end
  end
end