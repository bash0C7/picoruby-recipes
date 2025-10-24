require 'unimidi'
require 'uart'

puts "=== DDJ-400 Finger Drum → ATOM Matrix (Simple Protocol) にょん！==="

# プロセスID表示
pid = $$
puts "\n【プロセス情報】"
puts "PID: #{pid}"
puts "終了コマンド: kill -INT #{pid}"
puts "\n"

# MIDIデバイス検出
midi_devices = UniMIDI::Input.all
if midi_devices.empty?
  puts "エラー: MIDIデバイスが見つかりません"
  exit 1
end

puts "\n見つかったMIDI入力デバイス:"
midi_devices.each_with_index { |input, i| puts "#{i}: #{input.name}" }

print "\nMIDIデバイス番号を選択: "
midi_num = gets.chomp.to_i

input = midi_devices[midi_num]
input.open
puts "MIDI選択完了: #{input.name}"

# シリアルデバイス接続
serial_devices = Dir.glob('/dev/cu.usbserial*')
if serial_devices.empty?
  puts "エラー: シリアルデバイスが見つかりません"
  exit 1
end

puts "\n見つかったシリアルデバイス:"
serial_devices.each_with_index { |d, i| puts "#{i}: #{d}" }

print "\nシリアルデバイス番号を選択: "
serial_num = gets.chomp.to_i

serial = UART.open(serial_devices[serial_num], 115200)
puts "シリアル接続完了: #{serial_devices[serial_num]}"

# 【重要】起動待機（PicoRuby側の初期化完了を待つ）
puts "\n⏳ ATOM Matrix起動待機中（3秒）..."
sleep(3)

# General MIDI Drum Map
drum_names = {
  36 => "Kick",
  38 => "Snare",
  39 => "Hand Clap",
  41 => "Low Tom",
  42 => "Closed Hi-Hat",
  43 => "Low-Mid Tom",
  45 => "Mid Tom",
  46 => "Open Hi-Hat",
  47 => "Mid-Hi Tom",
  48 => "Hi Tom",
  49 => "Crash Cymbal",
  50 => "High Tom",
  51 => "Ride Cymbal",
  52 => "Chinese Cymbal",
  54 => "Tambourine",
  56 => "Cowbell"
}

# DECK1パッドマッピング
deck1_to_drum = {
  0 => 36,   # PAD 1: Kick
  1 => 38,   # PAD 2: Snare
  2 => 42,   # PAD 3: Closed Hi-Hat
  3 => 46,   # PAD 4: Open Hi-Hat
  4 => 49,   # PAD 5: Crash Cymbal
  5 => 51,   # PAD 6: Ride Cymbal
  6 => 39,   # PAD 7: Hand Clap
  7 => 56,   # PAD 8: Cowbell
}

# DECK2パッドマッピング
deck2_to_drum = {
  0 => 41,   # PAD 1: Low Tom
  1 => 43,   # PAD 2: Low-Mid Tom
  2 => 45,   # PAD 3: Mid Tom
  3 => 47,   # PAD 4: Mid-Hi Tom
  4 => 48,   # PAD 5: Hi Tom
  5 => 50,   # PAD 6: High Tom
  6 => 54,   # PAD 7: Tambourine
  7 => 52,   # PAD 8: Chinese Cymbal
}

puts "\n=== 🥁 Simple Drum Protocol 開始 ==="
puts ""
puts "【通信プロトコル】"
puts "  PC → ATOM: ドラムノート番号1バイト（36-56）"
puts "  例: 0x24(36) = Kick, 0x26(38) = Snare"
puts ""
puts "【DECK 1 (左側8パッド) - 基本ドラムキット】"
puts "  PAD1: キック      PAD5: クラッシュ"
puts "  PAD2: スネア      PAD6: ライド"
puts "  PAD3: クローズHH  PAD7: クラップ"
puts "  PAD4: オープンHH  PAD8: カウベル"
puts ""
puts "【DECK 2 (右側8パッド) - タム＆パーカッション】"
puts "  PAD1: ロータム    PAD5: ハイタム"
puts "  PAD2: ローミッド  PAD6: ハイタム"
puts "  PAD3: ミッドタム  PAD7: タンバリン"
puts "  PAD4: ミッドハイ  PAD8: チャイナ"
puts ""
puts "チェケラッチョ！！演奏開始にょん！"

# 送信カウンター（デバッグ用）
sent_count = 0

# メインループ
loop do
  begin
    messages = input.gets
    next unless messages && !messages.empty?
    
    messages.each do |message|
      next unless message && message[:data] && message[:data].length >= 2
      
      midi_bytes = message[:data]
      status = midi_bytes[0]
      channel = status & 0x0F
      
      # Note On のみ処理
      case status & 0xF0
      when 0x90  # Note On
        next unless midi_bytes.length >= 3
        
        pad_note = midi_bytes[1]
        velocity = midi_bytes[2]
        
        # ベロシティ0はNote Offと同等（スキップ）
        next if velocity == 0
        
        # チャンネルに応じてドラムノート決定
        drum_note = case channel
        when 7  # DECK 1
          deck1_to_drum[pad_note]
        when 9  # DECK 2
          deck2_to_drum[pad_note]
        else
          nil
        end
        
        if drum_note
          # 【核心部分】ドラムノート番号を1バイトで送信
          serial.write(drum_note.chr)
          
          sent_count += 1
          deck_name = (channel == 7) ? "DECK1" : "DECK2"
          instrument_name = drum_names[drum_note] || "Unknown"
          
          # 詳細ログ（HEX表示付き）
          puts "[#{sent_count}] #{deck_name} PAD#{pad_note+1} → 0x#{drum_note.to_s(16).upcase}(#{drum_note}) #{instrument_name}"
        end
      end
    end
    
  rescue => e
    puts "エラー: #{e.message}"
  end
  
  sleep(0.001)  # CPU負荷軽減
end
