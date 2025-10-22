require 'uart'
require 'io/console'

puts "=== PicoRuby Demo - PC Finger Drum ==="
puts "キーボード → MIDI → ATOM Matrix → MIDI Unit にょん！"

# キー→MIDIノート番号マッピング（General MIDI ドラムキット）
# チャンネル10（0-based: 9）のドラムキット
# （ノート番号は General MIDI GM Percussion Key Map に準拠）
key_notes = {
  # 下段（ドラム基本）
  'z' => 36,  # Kick (Bass Drum) - BD
  'x' => 38,  # Snare / Side Stick
  'c' => 42,  # Closed Hi-Hat
  'v' => 46,  # Open Hi-Hat
  'b' => 49,  # Crash Cymbal 1
  'n' => 51,  # Ride Cymbal 1
  'm' => 39,  # Hand Clap
  
  # 上段（タム・パーカッション）
  'a' => 41,  # Low Tom
  's' => 43,  # Low-Mid Tom / Hi Tom
  'd' => 45,  # Mid Tom
  'f' => 47,  # Mid-Hi Tom
  'g' => 48,  # Hi Tom
  'h' => 50,  # High Tom
  
  # 数字キー（追加パーカッション）
  '1' => 56,  # Cowbell
  '2' => 54,  # Tambourine
  '3' => 52,  # Chinese Cymbal
  '4' => 55   # Splash Cymbal
}

# シリアルデバイス検索
serial_devices = Dir.glob('/dev/cu.usbserial*')
if serial_devices.empty?
  puts "エラー: /dev/cu.usbserial* のデバイスが見つかりません"
  puts "ATOM Matrixを接続してください"
  exit 1
end

puts "\n見つかったシリアルデバイス:"
serial_devices.each_with_index do |device, i|
  puts "#{i}: #{device}"
end

print "\nシリアルデバイス番号を選択: "
device_num = gets.chomp.to_i

if device_num < 0 || device_num >= serial_devices.length
  puts "エラー: 無効なデバイス番号"
  exit 1
end

selected_device = serial_devices[device_num]

# ATOM Matrix接続
serial = UART.open(selected_device, 115200)
puts "接続完了: #{selected_device}"

puts "\n=== フィンガードラムモード開始 ==="
puts "キーマップ:"
puts "【下段】 z:キック x:スネア c:クローズHH v:オープンHH b:クラッシュ n:ライド m:クラップ"
puts "【上段】 a:ロータム s:ロー-ミッドタム d:ミッドタム f:ミッド-ハイタム g:ハイタム h:ハイタム上"
puts "【数字】 1:カウベル 2:タンバリン 3:チャイナ 4:スプラッシュ"
puts "qキーで終了"
puts ""
puts "チェケラッチョ！！演奏開始にょん！"

# Note Off管理
note_off_timers = {}

# コンソール設定
STDIN.raw!

begin
  loop do
    # キー入力チェック（10msタイムアウト）
    if IO.select([STDIN], nil, nil, 0.01)
      key = STDIN.getch.downcase
      
      # 終了チェック
      break if key == 'q'
      
      # ノート番号取得
      note = key_notes[key]
      next unless note
      
      # 前のタイマーキャンセル
      if note_off_timers[note]
        note_off_timers[note].kill
      end
      
      # ====== MIDI Note On メッセージ送信 ======
      # ステータスバイト構成:
      #   上位4bit: 0x9 (Note On メッセージ)
      #   下位4bit: 0x9 (Channel 10, 0-based indexing)
      #   → 結果: 0x99
      # データバイト1: ノート番号（36-96）
      # データバイト2: ベロシティ（0-127、0=ノートオフと同等）
      note_on = [0x99, note, 127]
      midi_string = note_on.map(&:chr).join
      serial.write(midi_string)
      
      puts "♪ #{key.upcase} → Note#{note} ON"
      
      # 150ms後にNote Off（ドラムは短め、推奨値: 100-200ms）
      note_off_timers[note] = Thread.new do
        sleep(0.15)
        
        # ====== MIDI Note Off メッセージ送信 ======
        # ステータスバイト構成:
        #   上位4bit: 0x8 (Note Off メッセージ)
        #   下位4bit: 0x9 (Channel 10, 0-based indexing)
        #   → 結果: 0x89
        # データバイト1: ノート番号
        # データバイト2: ベロシティ（Note Offでは通常0）
        note_off = [0x89, note, 0]
        midi_string = note_off.map(&:chr).join
        serial.write(midi_string)
        
        # デバッグ出力（オプション：コメントアウト推奨）
        # puts "♪ #{key.upcase} → Note#{note} OFF"
        
        # タイマー削除
        note_off_timers.delete(note)
      end
    end
  end

ensure
  # 残タイマーキャンセル
  note_off_timers.each_value(&:kill)
  
  # コンソール復元
  STDIN.cooked!
  puts "\n\n演奏終了にょん～！お疲れ様でした！"
end
