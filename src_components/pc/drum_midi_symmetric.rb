require 'unimidi'
require 'uart'

puts "=== DDJ-400 Finger Drum + FX Control にょん！==="

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

# 【重要】起動待機
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

# DECK1パッドマッピング（シンメトリック基本リズムパターン）
deck1_to_drum = {
  0 => 38,   # PAD 1: Snare
  1 => 46,   # PAD 2: Open Hi-Hat
  2 => 46,   # PAD 3: Open Hi-Hat
  3 => 38,   # PAD 4: Snare
  4 => 42,   # PAD 5: Closed Hi-Hat
  5 => 36,   # PAD 6: Kick
  6 => 36,   # PAD 7: Kick
  7 => 42,   # PAD 8: Closed Hi-Hat
}

# DECK2パッドマッピング（タム＆シンバル＆パーカッション）
deck2_to_drum = {
  0 => 41,   # PAD 1: Low Tom
  1 => 45,   # PAD 2: Mid Tom
  2 => 50,   # PAD 3: High Tom
  3 => 49,   # PAD 4: Crash Cymbal
  4 => 51,   # PAD 5: Ride Cymbal
  5 => 39,   # PAD 6: Hand Clap
  6 => 54,   # PAD 7: Tambourine
  7 => 49,   # PAD 8: Crash Cymbal
}

# FX状態管理
current_reverb_level = 9    # 0-9 (中間値)
current_chorus_level = 9    # 0-9 (中間値)

puts "\n=== 🥁 Enhanced Drum + FX Protocol にょん！==="
puts ""
puts "【通信プロトコル v2】"
puts "  ドラムノート: 36-56 (1byte)"
puts "  残響レベル:   1-10 (1byte, DECK1 FILTER)"
puts "  コーラス:     11-20 (1byte, DECK2 FILTER)"
puts ""

# DECK1パッドレイアウト表示
puts "【DECK 1 - シンメトリック基本リズムパターン】"
puts ""
puts "  1: #{drum_names[deck1_to_drum[0]].ljust(15)}  2: #{drum_names[deck1_to_drum[1]].ljust(15)}  3: #{drum_names[deck1_to_drum[2]].ljust(15)}  4: #{drum_names[deck1_to_drum[3]]}"
puts "  5: #{drum_names[deck1_to_drum[4]].ljust(15)}  6: #{drum_names[deck1_to_drum[5]].ljust(15)}  7: #{drum_names[deck1_to_drum[6]].ljust(15)}  8: #{drum_names[deck1_to_drum[7]]}"
puts "  FILTER: 残響（リバーブ）レベル 0-9"
puts ""

# DECK2パッドレイアウト表示
puts "【DECK 2 - タム＆シンバル＆パーカッション】"
puts ""
puts "  1: #{drum_names[deck2_to_drum[0]].ljust(15)}  2: #{drum_names[deck2_to_drum[1]].ljust(15)}  3: #{drum_names[deck2_to_drum[2]].ljust(15)}  4: #{drum_names[deck2_to_drum[3]]}"
puts "  5: #{drum_names[deck2_to_drum[4]].ljust(15)}  6: #{drum_names[deck2_to_drum[5]].ljust(15)}  7: #{drum_names[deck2_to_drum[6]].ljust(15)}  8: #{drum_names[deck2_to_drum[7]]}"
puts "  FILTER: コーラス（音の広がり）レベル 0-9"
puts ""

puts "チェケラッチョ！！演奏開始にょん！"

# 送信カウンター
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
      msg_type = status & 0xF0

      case msg_type
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
          # ドラムノート番号を1byteで送信
          serial.write(drum_note.chr)

          sent_count += 1
          deck_name = (channel == 7) ? "DECK1" : "DECK2"
          instrument_name = drum_names[drum_note] || "Unknown"

          puts "[#{sent_count}] 🥁 #{deck_name} PAD#{pad_note+1} → #{instrument_name} (#{drum_note})"
        end

      when 0xB0  # Control Change
        next unless midi_bytes.length >= 3
        next unless channel == 6  # Channel 7 (FILTER knobs)

        cc_num = midi_bytes[1]
        cc_value = midi_bytes[2]

        case cc_num
        when 23  # DECK1 FILTER (MSB)
          # MSB値（0-127）を10段階（0-9）にマッピング
          level = (cc_value * 10 / 128).to_i
          level = 9 if level > 9

          # 値が変化した場合のみ送信
          if level != current_reverb_level
            current_reverb_level = level

            # 残響レベルとして送信（1-10）
            send_value = level + 1
            serial.write(send_value.chr)

            sent_count += 1
            puts "[#{sent_count}] 🌊 REVERB: Level #{level} (raw:#{cc_value} → #{send_value})"
          end

        when 24  # DECK2 FILTER (MSB)
          # MSB値（0-127）を10段階（0-9）にマッピング
          level = (cc_value * 10 / 128).to_i
          level = 9 if level > 9

          # 値が変化した場合のみ送信
          if level != current_chorus_level
            current_chorus_level = level

            # コーラスレベルとして送信（11-20）
            send_value = level + 11
            serial.write(send_value.chr)

            sent_count += 1
            puts "[#{sent_count}] 🎵 CHORUS: Level #{level} (raw:#{cc_value} → #{send_value})"
          end
        end
      end
    end

  rescue => e
    puts "エラー: #{e.message}"
  end

  sleep(0.001)  # CPU負荷軽減
end
