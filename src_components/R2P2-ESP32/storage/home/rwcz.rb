require 'uart'
require 'ws2812'
require 'i2c'
require 'mpu6886'

# LED位置マッピング（PAD 36-56 → LED 0-15 + nil）
DRUM_LED=[0,nil,1,nil,nil,2,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,3,nil,nil,nil,4,5,nil,nil,nil,nil,nil,nil,6,nil,7,8,nil,9,nil,10,nil,11,12,nil,13,nil,14,nil,15]

# UART初期化
$pc=UART.new(unit: :ESP32_UART0, baudrate: 115200)
sleep_ms(10)
$md=UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)
sleep_ms(10)

# LED初期化
$led=WS2812.new(RMTDriver.new(22))
$co=Array.new(60, 0x030303)  # ベース照明: 全て薄暗い白
sleep_ms(10)

# 加速度センサー初期化
begin
  $i2c=I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
  sleep_ms(100)
  $u=MPU6886.new($i2c)
  sleep_ms(100)
  $u.accel_range=MPU6886::ACCEL_RANGE_2G
  sleep_ms(100)
rescue => e
  puts "MPU6886 Error: #{e.message}"
  $u=nil
end

# MIDI音源初期化（TR-808キット）
$pc.clear_rx_buffer
$md.clear_rx_buffer
$md.write((0xC9).chr+(25).chr)

# グローバル変数
$tick=0
$pad_history=Array.new(5, nil)  # PAD履歴キュー（最大5個）
$history_idx=0                  # 書き込み位置
$prev_accel=[0,0,0]            # 前回加速度 [X,Y,Z]
$current_color=[0,0]           # 現在色 [R,B]

puts "=== New LED Strategy ==="
puts "Base: 0x030303 (very dim white)"
puts "History: 5 PADs green highlight"
puts "Accel: Speed->Red, Up->Blue"

loop do
  $tick += 1

  # UART受信処理
  while $pc.bytes_available > 0
    data = $pc.read(1)
    next unless data && data.length == 1
    cmd = data[0].ord

    case cmd
    when 36..56  # ドラムノート
      # MIDI出力
      $md.write((0x99).chr + cmd.chr + (0x7F).chr)

      # PAD履歴に追加（リングバッファ）
      $pad_history[$history_idx] = cmd
      $history_idx = ($history_idx + 1) % 5

      # 履歴表示（nilを除外）
      hist = []
      $pad_history.each {|h| hist << h if h}
      puts "PAD:#{cmd} history=#{hist.inspect}"

    when 1..10   # リバーブ
      $md.write((0xB9).chr + 91.chr + (((cmd-1)*127/9).to_i).chr)
    when 11..20  # コーラス
      $md.write((0xB9).chr + 93.chr + (((cmd-11)*127/9).to_i).chr)
    end
  end

  # 15ループごとに加速度サンプリング
  if $tick % 15 == 0 && $u
    a = $u.acceleration
    ax = (a[:x] * 100).to_i
    ay = (a[:y] * 100).to_i
    az = (a[:z] * 100).to_i

    # 赤: 動きの速さ（3軸合成差分）
    speed = (ax-$prev_accel[0]).abs + (ay-$prev_accel[1]).abs + (az-$prev_accel[2]).abs
    red = (speed.clamp(0,300) * 255 / 300).to_i

    # 青: 上下動き（Z軸絶対値）
    blue = (az.abs.clamp(0,200) * 255 / 200).to_i

    $current_color = [red, blue]
    $prev_accel = [ax, ay, az]

    puts "Accel: spd=#{speed} R=#{red} B=#{blue}" if $tick % 150 == 0
  end

  # LED更新（全60個を1ループで処理）
  60.times do |i|
    # このLED位置に対応するPADを逆引き
    pad_idx = DRUM_LED.index(i)

    if pad_idx && $pad_history.include?(36 + pad_idx)
      # 履歴にあるPAD → 緑強調 + 加速度色
      r = $current_color[0]
      g = 0xFF
      b = $current_color[1]
    else
      # 履歴にないPAD → 白弱（ベース照明）
      r = g = b = 0x03
    end

    # ビット演算でRGB合成
    $co[i] = (r<<16) | (g<<8) | b
  end

  # LED表示
  $led.show_hex(*$co)

  sleep_ms(1)
end
