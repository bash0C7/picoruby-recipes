require 'uart'
require 'io/console'

puts "PC キーボード → MIDI Bridge 開始にょん！ qで終了するよ"

# キー→MIDIノート番号のマッピング  
key_notes = {
  'z' => 57,  # A3
  'x' => 59,  # B3
  'c' => 60,  # C4 (Middle C)
  'v' => 62,  # D4
  'b' => 64,  # E4
  'n' => 65,  # F4
  'm' => 67,  # G4
  ',' => 69,  # A4
  '.' => 71,  # B4
  '/' => 72   # C5
}

# 利用可能なシリアルデバイスを取得
serial_devices = Dir.glob('/dev/cu.usbserial*')
if serial_devices.empty?
  puts "エラー: /dev/cu.usbserial* のデバイスが見つかりません"
  exit 1
end

puts "\n見つかったシリアルデバイス:"
serial_devices.each_with_index do |device, i|
  puts "#{i}: #{device}"
end

print "\nシリアルデバイス番号を選択: "
serial_device_num = gets.chomp.to_i

if serial_device_num < 0 || serial_device_num >= serial_devices.length
  puts "エラー: 無効なシリアルデバイス番号です"
  exit 1
end

selected_serial_device = serial_devices[serial_device_num]

# ATOM Matrixとのシリアル接続
serial = UART.open(selected_serial_device, 115200)
puts "シリアル接続完了: #{selected_serial_device}"

puts "\nキーボード演奏モード開始にょん！"
puts "対応キー: z x c v b n m , . /"
puts "音階:   A3 B3 C4 D4 E4 F4 G4 A4 B4 C5"
puts "qキーで終了"
puts "演奏開始！チェケラッチョ！！"

# Note Off管理用
note_off_timers = {}

# コンソール設定
STDIN.raw!

begin
  loop do
    # ノンブロッキングでキー入力をチェック（100ms タイムアウト）
    if IO.select([STDIN], nil, nil, 0.1)
      key = STDIN.getch.downcase
      
      # 終了チェック
      break if key == 'q'
      
      # 対応するノート番号を取得
      note = key_notes[key]
      next unless note
      
      # 前のNote Offタイマーがあればキャンセル
      if note_off_timers[note]
        note_off_timers[note].kill
      end
      
      # Note On送信 (90: チャンネル1, note, velocity 127)
      note_on = [0x90, note, 127]
      midi_string = note_on.map(&:chr).join
      serial.write(midi_string)
      
      puts "♪ #{key.upcase} → Note#{note} ON"
      
      # 500ms後にNote Offを送信するタイマーを開始
      note_off_timers[note] = Thread.new do
        sleep(0.5)
        
        # Note Off送信 (80: チャンネル1, note, velocity 0)
        note_off = [0x80, note, 0]
        midi_string = note_off.map(&:chr).join
        serial.write(midi_string)
        
        puts "♪ #{key.upcase} → Note#{note} OFF"
        
        # タイマーを削除
        note_off_timers.delete(note)
      end
    end
    
    # CPU負荷軽減
    sleep(0.01)  # 10ms待機
  end

ensure
  # 残っているタイマーをすべてキャンセル
  note_off_timers.each_value(&:kill)
  
  # コンソール設定を復元
  STDIN.cooked!
  puts "\n\n演奏終了にょん～！"
end
