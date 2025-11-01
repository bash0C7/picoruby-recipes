require 'uart'
require 'io/console'
require 'thread'

puts "=== PicoRuby Finger Drum - Auto Play 16-beat Version ==="
puts "キーボード → UART → ATOM Matrix → MIDI Unit にょん！"
$stdout.flush

# ドラムノート定義
KICK = 36           # バスドラム
SNARE = 38          # スネア
CLAP = 39           # クラップ
HI_HAT_CLOSE = 42   # ハイハット（クローズ）
HI_HAT_OPEN = 46    # ハイハット（オープン）
HIGH_TOM = 50       # ハイタム
MID_TOM = 47        # ミッドタム
LOW_TOM = 41        # ロータム

# 16ビートパターン（120bpm）
# 1 quarter note = 0.5秒 → 1 16th note = 0.125秒 = 125ms
# 奇数ステップ: 表拍、偶数ステップ: 裏拍（ハイハット、タム系を配置）
drum_pattern = [
  KICK,           # Step 1  (1拍目)
  HI_HAT_CLOSE,   # Step 2  (1拍目の裏)
  SNARE,          # Step 3  (2拍目)
  HI_HAT_CLOSE,   # Step 4  (2拍目の裏)
  KICK,           # Step 5  (3拍目)
  HI_HAT_CLOSE,   # Step 6  (3拍目の裏)
  SNARE,          # Step 7  (4拍目)
  HI_HAT_OPEN,    # Step 8  (4拍目の裏、オープンで開放感)
  KICK,           # Step 9  (5拍目)
  MID_TOM,        # Step 10 (5拍目の裏、タム系で音彩)
  SNARE,          # Step 11 (6拍目)
  HI_HAT_CLOSE,   # Step 12 (6拍目の裏)
  KICK,           # Step 13 (7拍目)
  CLAP,           # Step 14 (7拍目の裏、クラップでアクセント)
  SNARE,          # Step 15 (8拍目)
  LOW_TOM         # Step 16 (8拍目の裏、ロータムで締め)
]

# シリアルデバイス接続
serial_devices = Dir.glob('/dev/cu.usbserial*')
if serial_devices.empty?
  puts "エラー: デバイスが見つかりません"
  exit 1
end

puts "\n見つかったシリアルデバイス:"
$stdout.flush
serial_devices.each_with_index { |d, i| puts "#{i}: #{d}" }
$stdout.flush

print "\nシリアルデバイス番号を選択: "
$stdout.flush
device_num = gets.chomp.to_i

if device_num < 0 || device_num >= serial_devices.length
  puts "エラー: 無効なデバイス番号"
  exit 1
end

serial = UART.open(serial_devices[device_num], 115200)
puts "接続完了: #{serial_devices[device_num]}"
$stdout.flush

# エフェクト設定
puts "\n【初期設定】"
$stdout.flush
print "リバーブレベル (0-9, デフォルト5): "
$stdout.flush
reverb_input = gets.chomp
reverb_level = reverb_input.empty? ? 5 : reverb_input.to_i.clamp(0, 9)

print "コーラスレベル (0-9, デフォルト5): "
$stdout.flush
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
$stdout.flush

puts "\n=== 16ビート自動演奏モード開始 ==="
puts "バスドラム + スネア + クラップ + ハイハット + タム系の豊かなドラムパターン！"
puts "裏拍にハイハット・タムをちりばめた16ビート展開"
puts "120bpm で自動演奏中... q キーで終了\n"
$stdout.flush

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
      CLAP => "Clap",
      HI_HAT_CLOSE => "HiHat-",
      HI_HAT_OPEN => "HiHat+",
      HIGH_TOM => "Tom-H",
      MID_TOM => "Tom-M",
      LOW_TOM => "Tom-L"
    }

    $stdout.puts "♪ Step #{(step % drum_pattern.length) + 1}: #{drum_names[note]}"
    $stdout.flush

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
