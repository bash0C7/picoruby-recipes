require 'uart'
require 'io/console'
require 'thread'

puts "=== PicoRuby Finger Drum - Auto Play 16-beat Version ==="
puts "キーボード → UART → ATOM Matrix → MIDI Unit にょん！"

# ドラムノート定義
KICK = 36   # バスドラム
SNARE = 38  # スネア
CRASH = 49  # クラッシュシンバル
CLAP = 39   # クラップ

# 16ビートパターン（120bpm）
# 1 quarter note = 0.5秒 → 1 16th note = 0.125秒 = 125ms
drum_pattern = [
  KICK,  # Step 1
  KICK,  # Step 2
  SNARE, # Step 3
  KICK,  # Step 4
  KICK,  # Step 5
  CLAP,  # Step 6
  SNARE, # Step 7
  KICK,  # Step 8
  CRASH, # Step 9 (バリエーション)
  KICK,  # Step 10
  SNARE, # Step 11
  KICK,  # Step 12
  KICK,  # Step 13
  CLAP,  # Step 14
  SNARE, # Step 15
  KICK   # Step 16
]

# シリアルデバイス接続
serial_devices = Dir.glob('/dev/cu.usbserial*')
if serial_devices.empty?
  puts "エラー: デバイスが見つかりません"
  exit 1
end

puts "\n見つかったシリアルデバイス:"
serial_devices.each_with_index { |d, i| puts "#{i}: #{d}" }

print "\nシリアルデバイス番号を選択: "
device_num = gets.chomp.to_i

if device_num < 0 || device_num >= serial_devices.length
  puts "エラー: 無効なデバイス番号"
  exit 1
end

serial = UART.open(serial_devices[device_num], 115200)
puts "接続完了: #{serial_devices[device_num]}"

# エフェクト設定
puts "\n【初期設定】"
print "リバーブレベル (0-9, デフォルト5): "
reverb_input = gets.chomp
reverb_level = reverb_input.empty? ? 5 : reverb_input.to_i.clamp(0, 9)

print "コーラスレベル (0-9, デフォルト5): "
chorus_input = gets.chomp
chorus_level = chorus_input.empty? ? 5 : chorus_input.to_i.clamp(0, 9)

# 初期化送信
serial.write((reverb_level + 1).chr)
sleep(0.05)
serial.write((chorus_level + 11).chr)
sleep(0.05)

puts "\n✓ リバーブ: #{reverb_level}"
puts "✓ コーラス: #{chorus_level}"
puts "✓ ベロシティ: 127 (PicoRuby側で固定)"

puts "\n=== 16ビート自動演奏モード開始 ==="
puts "バスドラム + スネア + クラッシュ + クラップで16ビート展開！"
puts "120bpm で自動演奏中... q キーで終了\n"

# グローバルフラグ
$should_exit = false

# キー入力監視スレッド
input_thread = Thread.new do
  STDIN.raw!
  begin
    loop do
      if IO.select([STDIN], nil, nil, 0.1)
        key = STDIN.read_nonblock(1) rescue nil
        if key && key.downcase == 'q'
          $should_exit = true
          break
        end
      end
    end
  ensure
    STDIN.cooked!
  end
end

# 演奏ループ
begin
  step = 0
  loop do
    break if $should_exit

    note = drum_pattern[step % drum_pattern.length]

    # シリアル送信
    serial.write(note.chr)

    # ドラム名表示
    drum_names = {
      KICK => "Kick",
      SNARE => "Snare",
      CRASH => "Crash",
      CLAP => "Clap"
    }

    puts "♪ Step #{(step % drum_pattern.length) + 1}: #{drum_names[note]}"

    # 120bpm の 16ビート = 125ms 間隔
    sleep(0.125)

    step += 1
  end

rescue Interrupt
  $should_exit = true

ensure
  STDIN.cooked! rescue nil
  input_thread.kill
  puts "\r\nアディオス！にょん！"
  exit 0
end
