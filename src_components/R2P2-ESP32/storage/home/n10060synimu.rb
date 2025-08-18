# ATOM Matrix外付けLED光源ペンライト + 加速度センサー連動
require 'unitasr'
require 'ws2812'
require 'uart'
require 'mpu6886'

# LED設定
led_pin = 22
led_count = 90
led = WS2812.new(RMTDriver.new(led_pin))
colors = Array.new(led_count) { [200, 100, 0] }

# UART設定
asr = UnitASR.new(UART.new(unit: :ESP32_UART1, baudrate: 115200, txd_pin: 26, rxd_pin: 32))
midi = UART.new(unit: :ESP32_UART0, baudrate: 31250, txd_pin: 23, rxd_pin: 33)

# IMU設定
i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G

# 変数
base_x = 0.0
base_y = 0.0
base_z = 0.0
cal = false
scroll = 0

# チャタリング防止用
last_nx = 60
last_ny = 60  
last_nz = 60
sound_timer_x = 0
sound_timer_y = 0
sound_timer_z = 0
motion_threshold = 0.15

# 初期化
sleep_ms(1000)

# ASRコマンド
asr.on(0x30) do  # "ok" - キャリブレーション
  accel = mpu.acceleration
  base_x = accel[:x]
  base_y = accel[:y] 
  base_z = accel[:z]
  cal = true
end

# メインループ
loop do
  asr.update
  
  if cal
    # 加速度取得
    accel = mpu.acceleration
    dx = accel[:x] - base_x
    dy = accel[:y] - base_y
    dz = accel[:z] - base_z
    
    # 絶対値
    ax = dx < 0 ? -dx : dx
    ay = dy < 0 ? -dy : dy
    az = dz < 0 ? -dz : dz
    
    # RGB計算
    r = (ax * 2550).to_i
    g = (ay * 2550).to_i  
    b = (az * 2550).to_i
    r = r > 255 ? 255 : r
    g = g > 255 ? 255 : g
    b = b > 255 ? 255 : b
    
    # MIDI音程計算
    nx = (ax * 600).to_i + 36
    ny = (ay * 600).to_i + 36
    nz = (az * 600).to_i + 36
    nx = nx > 96 ? 96 : nx
    ny = ny > 96 ? 96 : ny
    nz = nz > 96 ? 96 : nz
    
    # チャタリング防止MIDI再生
    # X軸ギター
    if ax > motion_threshold
      if nx != last_nx
        midi.write((0x80 + 1).chr + last_nx.chr + 0.chr)  # 前のNote Off
        midi.write((0xC0 + 1).chr + 24.chr)  # ギター
        midi.write((0x90 + 1).chr + nx.chr + 80.chr)  # Note On
        last_nx = nx
        sound_timer_x = 20  # 1秒間鳴らす
      end
      sound_timer_x = sound_timer_x > 0 ? sound_timer_x - 1 : 0
    else
      if sound_timer_x == 0 && last_nx != 60
        midi.write((0x80 + 1).chr + last_nx.chr + 0.chr)  # Note Off
        last_nx = 60
      end
      sound_timer_x = sound_timer_x > 0 ? sound_timer_x - 1 : 0
    end
    
    # Y軸オルガン  
    if ay > motion_threshold
      if ny != last_ny
        midi.write((0x80 + 2).chr + last_ny.chr + 0.chr)
        midi.write((0xC0 + 2).chr + 19.chr)  # オルガン
        midi.write((0x90 + 2).chr + ny.chr + 80.chr)
        last_ny = ny
        sound_timer_y = 20
      end
      sound_timer_y = sound_timer_y > 0 ? sound_timer_y - 1 : 0
    else
      if sound_timer_y == 0 && last_ny != 60
        midi.write((0x80 + 2).chr + last_ny.chr + 0.chr)
        last_ny = 60
      end
      sound_timer_y = sound_timer_y > 0 ? sound_timer_y - 1 : 0
    end
    
    # Z軸ベース
    if az > motion_threshold
      if nz != last_nz
        midi.write((0x80 + 3).chr + last_nz.chr + 0.chr)
        midi.write((0xC0 + 3).chr + 33.chr)  # ベース
        midi.write((0x90 + 3).chr + nz.chr + 80.chr)
        last_nz = nz
        sound_timer_z = 20
      end
      sound_timer_z = sound_timer_z > 0 ? sound_timer_z - 1 : 0
    else
      if sound_timer_z == 0 && last_nz != 60
        midi.write((0x80 + 3).chr + last_nz.chr + 0.chr)
        last_nz = 60
      end
      sound_timer_z = sound_timer_z > 0 ? sound_timer_z - 1 : 0
    end
    
    # LEDスクロール
    scroll = (scroll + 2) % led_count
    led_count.times do |i|
      pos = (i + scroll) % led_count
      fade = (pos * 2) % 256
      colors[i] = [(r * fade / 255), (g * fade / 255), (b * fade / 255)]
    end
  end
  
  led.show_rgb(*colors)
  sleep_ms 50
end
