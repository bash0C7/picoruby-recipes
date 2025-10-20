# PicoRuby フィンガードラムデモ - 本番版
# LED光源 + IMU加速度 + MIDI音源 + PC通信統合
# ATOM Matrix + 外付け60LED + MPU6886 + SAM2695

require 'i2c'
require 'mpu6886'
require 'ws2812'
require 'uart'

# グローバル変数群
$i2c = nil
$led = nil
$pc = nil
$md = nil
$mpu = nil

$co = []
$bx = [0, 0, 0]
$cb = 0xFF8040

$midi_state = 0
$midi_status = 0
$midi_note = 0

def init_hardware
  puts "=== Hardware Init Start ==="
  
  puts "I2C init..."
  $i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
  sleep_ms(100)
  
  puts "LED init..."
  $led = WS2812.new(RMTDriver.new(22))
  sleep_ms(100)
  
  puts "PC UART init..."
  $pc = UART.new(unit: :ESP32_UART0, baudrate: 115200)
  sleep_ms(100)
  
  puts "MIDI UART init..."
  $md = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 26, rxd_pin: 32)
  sleep_ms(100)
  
  puts "MPU6886 init..."
  $mpu = MPU6886.new($i2c)
  $mpu.accel_range = MPU6886::ACCEL_RANGE_4G
  sleep_ms(100)
  
  puts "LED buffer init..."
  $co = Array.new(60, 0xFF8040)
  
  puts "Calibrating MPU..."
  calibrate_mpu
  
  puts "MIDI Program Change..."
  $md.write((0xC0).chr + (83).chr)
  sleep_ms(100)
  
  puts "=== Hardware Init Complete ==="
end

def calibrate_mpu
  sx = sy = sz = 0
  
  5.times do |i|
    puts "  Cal #{i+1}/5"
    a = $mpu.acceleration
    sx += (a[:x] * 100).to_i
    sy += (a[:y] * 100).to_i
    sz += (a[:z] * 100).to_i
    sleep_ms(100)
  end
  
  $bx = [sx / 5, sy / 5, sz / 5]
  puts "  Calibration done: #{$bx}"
end

def update_color_from_accel
  a = $mpu.acceleration
  ac = [(a[:x] * 100).to_i, (a[:y] * 100).to_i, (a[:z] * 100).to_i]
  
  dx = ac[0] - $bx[0]
  dy = ac[1] - $bx[1]
  dz = ac[2] - $bx[2]
  
  # Accel → RGB (0-7 range)
  rx = (dx + 200) >> 6
  ry = (dy + 200) >> 6
  rz = (dz + 200) >> 6
  
  rx = 0 if rx < 0
  rx = 7 if rx > 7
  ry = 0 if ry < 0
  ry = 7 if ry > 7
  rz = 0 if rz < 0
  rz = 7 if rz > 7
  
  r = rx << 5
  g = ry << 5
  b = rz << 5
  $cb = (r << 16) | (g << 8) | b
  
  # MIDI CC送信 (71=Filter, 74=Resonance, 91=Reverb)
  cc_list = [71, 74, 91]
  3.times do |k|
    d = ac[k] - $bx[k]
    v = ((d + 200) * 127 / 400).to_i
    v = 0 if v < 0
    v = 127 if v > 127
    $md.write((0xB0).chr + cc_list[k].chr + v.chr)
  end
end

def process_pc_midi
  return unless $pc.bytes_available > 0
  
  dt = $pc.read
  return unless dt && dt.length > 0
  
  # PCから受け取ったMIDIをMIDIモジュールにも流す
  $md.write(dt)
  
  # ステートマシンでパース
  i = 0
  while i < dt.length
    b = dt[i].ord
    
    case $midi_state
    when 0
      # ステータスバイト待機
      if b == 0x90 || b == 0x80 || b == 0x99 || b == 0x89
        $midi_status = b
        $midi_state = 1
      end
    when 1
      # ノートバイト待機
      $midi_note = b
      $midi_state = 2
    when 2
      # ベロシティ/値
      if ($midi_status == 0x90 || $midi_status == 0x99) && b > 0
        # Note On
        if $midi_note >= 36 && $midi_note <= 84
          pos = (($midi_note - 36) % 12) * 5 + (($midi_note - 36) / 12)
          if pos >= 0 && pos < 60
            $co[pos] = $cb
          end
        end
      else
        # Note Off
        if $midi_note >= 36 && $midi_note <= 84
          pos = (($midi_note - 36) % 12) * 5 + (($midi_note - 36) / 12)
          if pos >= 0 && pos < 60
            $co[pos] = 0
          end
        end
      end
      $midi_state = 0
    end
    
    i += 1
  end
end

def update_leds
  $led.show_hex(*$co)
end

def fade_leds
  i = 0
  while i < 60
    if $co[i] > 5
      $co[i] = ($co[i] * 97 / 100)
    else
      $co[i] = 0
    end
    i += 1
  end
end

# メイン処理
begin
  init_hardware
  
  puts ""
  puts "=== Demo Start ==="
  puts "PC接続待ち..."
  puts ""
  
  loop_count = 0
  accel_update_interval = 5
  
  loop do
    loop_count += 1
    
    # 加速度更新（5ループごと）
    if loop_count % accel_update_interval == 0
      update_color_from_accel
    end
    
    # PC MIDI受信処理
    process_pc_midi
    
    # LED更新
    fade_leds
    update_leds
    
    # デバッグ出力
    if loop_count % 200 == 0
      puts "Loop: #{loop_count}, Accel: #{$bx}, Color: 0x#{$cb.to_s(16)}"
    end
    
    sleep_ms(20)
  end
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
end
