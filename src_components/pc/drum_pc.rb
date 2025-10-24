require 'uart'
require 'io/console'

puts "=== PicoRuby Demo - PC Finger Drum ==="
puts "キーボード → MIDI → ATOM Matrix → MIDI Unit にょん！"

# プロセスID表示と終了コマンド
pid = $$
puts "\n【プロセス情報】"
puts "PID: #{pid}"
puts "終了コマンド: kill -INT #{pid}"
puts "\n"
puts "チェケラッチョ！！演奏開始にょん！"

# ===== ドラムキット定義 =====
drum_kits = {
  0 => "Standard Drum Kit",
  8 => "Room Drum Kit",
  16 => "Power Drum Kit",
  24 => "Electronic Drum Kit",
  25 => "TR-808 Drum Kit (Emulated)",
  26 => "TR-909 Drum Kit (Emulated)",
  32 => "Jazz Drum Kit",
  40 => "Brush Drum Kit"
}

# General MIDI ドラムキット（Channel 10）
key_notes = {
  # 下段（ドラム基本）
  'z' => 36,  # Kick (Bass Drum)
  'x' => 38,  # Snare
  'c' => 42,  # Closed Hi-Hat
  'v' => 46,  # Open Hi-Hat
  'b' => 49,  # Crash Cymbal 1
  'n' => 51,  # Ride Cymbal 1
  'm' => 39,  # Hand Clap
  
  # 上段（タム・パーカッション）
  'a' => 41,  # Low Tom
  's' => 43,  # Low-Mid Tom
  'd' => 45,  # Mid Tom
  'f' => 47,  # Mid-Hi Tom
  'g' => 48,  # Hi Tom
  'h' => 50,  # High Tom
  
  # 数字キー
  '1' => 56,  # Cowbell
  '2' => 54,  # Tambourine
  '3' => 52,  # Chinese Cymbal
  '4' => 55   # Splash Cymbal
}

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

# ===== ドラムキット選択 =====
puts "\n【利用可能なドラムキット】"
drum_kits.each do |prog, name|
  puts "  #{prog.to_s.rjust(2)}: #{name}"
end

print "\nドラムキットを選択 (デフォルト 0): "
kit_choice = gets.chomp.to_i
kit_choice = 0 unless drum_kits.key?(kit_choice)

# ドラムキット選択を送信 (Program Change on Channel 10 = 0xC9)
serial.write([0xC9, kit_choice].map(&:chr).join)
sleep(0.1)
puts "✓ ドラムキット選択: #{drum_kits[kit_choice]}"

puts "\n=== フィンガードラムモード開始 ==="
puts "【下段】 z:キック x:スネア c:クローズHH v:オープンHH b:クラッシュ n:ライド m:クラップ"
puts "【上段】 a-h:タム各種"
puts "【数字】 1:カウベル 2:タンバリン 3:チャイナ 4:スプラッシュ"
puts "同時押し対応！ キック+スネア等、複数キーを同時に叩けますにょん！"
puts "Ctrl+C で終了\n"
puts "チェケラッチョ！！演奏開始にょん！"

STDIN.raw!

begin
  loop do
    # バッファに溜まった全キーを読み取る(sec単位タイムアウト）
    if IO.select([STDIN], nil, nil, 0.01)
      keys_pressed = []
      
      # バッファが空になるまで全キー読み取り（同時押し検知）
      loop do
        key = STDIN.read_nonblock(1) rescue nil
        break unless key
        
        key = key.downcase
        
        # 有効なキーのみ収集
        if key_notes[key]
          keys_pressed << key
        end
      end
      
      # 収集したキーをすべて同時送信（ドラムワンショット）
      if keys_pressed.any?
        # 複数キーを一気に送信（ポリフォニック）
        keys_pressed.each do |key|
          note = key_notes[key]
          # Note On on Channel 10 (0x99) with velocity 127
          note_on = [0x99, note, 127]
          serial.write(note_on.map(&:chr).join)
        end
        
        # デバッグ表示
        keys_str = keys_pressed.map(&:upcase).join('+')
        notes_str = keys_pressed.map { |k| key_notes[k] }.join('+')
        puts "♪ #{keys_str} → #{notes_str}"
      end
    end
  end

rescue => e
  cleanup
end
