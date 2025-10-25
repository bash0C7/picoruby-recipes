require 'uart'
require 'ws2812'
require 'i2c'
require 'mpu6886'

# UART初期化
pc_uart=UART.new(unit: :ESP32_UART0, baudrate: 115200)
sleep_ms(10)
md_uart=UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)
sleep_ms(10)

# LED初期化
led_strip=WS2812.new(RMTDriver.new(22))
led_colors=Array.new(60, 0x030303)
sleep_ms(10)

# 加速度センサー初期化
begin
  i2c_bus=I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
  sleep_ms(100)
  accel_sensor=MPU6886.new(i2c_bus)
  sleep_ms(100)
  accel_sensor.accel_range=MPU6886::ACCEL_RANGE_2G
  sleep_ms(100)
rescue => e
  puts "MPU6886 Error: #{e.message}"
  accel_sensor=nil
end

# MIDI音源初期化（TR-808キット）
pc_uart.clear_rx_buffer
md_uart.clear_rx_buffer
md_uart.write((0xC9).chr+(25).chr)

# ローカル変数（グローバル変数ゼロ）
tick_count=0
pad_history=Array.new(5, nil)
history_idx=0
prev_ax=0
prev_ay=0
prev_az=0
color_red=0
color_blue=0

puts "=== New LED Strategy ==="
puts "Base: 0x030303 (very dim white)"
puts "History: 5 PADs green highlight"
puts "Accel: Speed->Red, Up->Blue"

loop do
  tick_count += 1

  # UART受信処理
  while pc_uart.bytes_available > 0
    uart_data = pc_uart.read(1)
    next unless uart_data && uart_data.length == 1
    cmd_byte = uart_data[0].ord

    case cmd_byte
    when 36..56  # ドラムノート
      # MIDI出力
      md_uart.write((0x99).chr + cmd_byte.chr + (0x7F).chr)

      # PAD履歴に追加（リングバッファ）
      pad_history[history_idx] = cmd_byte
      history_idx = (history_idx + 1) % 5

      # 履歴表示（nilを除外）
      hist_display = []
      pad_history.each {|h| hist_display << h if h}
      puts "PAD:#{cmd_byte} history=#{hist_display.inspect}"

    when 1..10   # リバーブ
      md_uart.write((0xB9).chr + 91.chr + (((cmd_byte-1)*127/9).to_i).chr)
    when 11..20  # コーラス
      md_uart.write((0xB9).chr + 93.chr + (((cmd_byte-11)*127/9).to_i).chr)
    end
  end

  # 15ループごとに加速度サンプリング
  if tick_count % 15 == 0 && accel_sensor
    accel_data = accel_sensor.acceleration
    curr_ax = (accel_data[:x] * 100).to_i
    curr_ay = (accel_data[:y] * 100).to_i
    curr_az = (accel_data[:z] * 100).to_i

    # 赤: 動きの速さ（3軸合成差分）
    speed_val = (curr_ax-prev_ax).abs + (curr_ay-prev_ay).abs + (curr_az-prev_az).abs
    color_red = (speed_val.clamp(0,300) * 255 / 300).to_i

    # 青: 上下動き（Z軸絶対値）
    color_blue = (curr_az.abs.clamp(0,200) * 255 / 200).to_i

    prev_ax = curr_ax
    prev_ay = curr_ay
    prev_az = curr_az

    puts "Accel: spd=#{speed_val} R=#{color_red} B=#{color_blue}" if tick_count % 150 == 0
  end

  # LED更新（全60個）
  # ベース照明で初期化
  60.times {|idx| led_colors[idx] = 0x030303}

  # 履歴にあるPADのLED位置を緑に点灯（履歴位置もファクター）
  5.times do |hist_pos|
    pad_note = pad_history[hist_pos]
    next unless pad_note

    # 疑似ランダムでLED位置を3-5個生成（履歴位置も加味）
    seed_val = pad_note * 7 + hist_pos * 11
    num_positions = 3 + (pad_note % 3)

    num_positions.times do |pos_idx|
      # 中心LED位置
      center_pos = (seed_val + pos_idx * 13 + pos_idx * pos_idx * 5) % 60
      center_color = (color_red<<16) | (0xFF<<8) | color_blue

      # 周囲5個を輝度落として点灯（中心が最優先）
      5.times do |spread_idx|
        spread_pos = (center_pos + spread_idx - 2) % 60

        # 輝度計算（中心=100%, ±1=70%, ±2=40%）
        brightness = spread_idx == 2 ? 0xFF : (spread_idx == 1 || spread_idx == 3 ? 0xB3 : 0x66)

        # 既存の色と比較して明るい方を採用（強い光優先）
        new_r = ((color_red * brightness) >> 8)
        new_g = ((0xFF * brightness) >> 8)
        new_b = ((color_blue * brightness) >> 8)
        new_color = (new_r<<16) | (new_g<<8) | new_b

        # 既存色のRGB成分を取り出し
        old_r = (led_colors[spread_pos] >> 16) & 0xFF
        old_g = (led_colors[spread_pos] >> 8) & 0xFF
        old_b = led_colors[spread_pos] & 0xFF

        # 各成分の最大値を採用（明るい方優先）
        final_r = new_r > old_r ? new_r : old_r
        final_g = new_g > old_g ? new_g : old_g
        final_b = new_b > old_b ? new_b : old_b

        led_colors[spread_pos] = (final_r<<16) | (final_g<<8) | final_b
      end
    end
  end

  # LED表示
  led_strip.show_hex(*led_colors)

  sleep_ms(1)
end
