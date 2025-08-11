require 'unimidi'
require 'uart'

# pc_unimidi.rb
require 'unimidi'
require 'uart'

# 利用可能なMIDI入力デバイスを表示
puts "利用可能なMIDI入力デバイス:"
UniMIDI::Input.all.each_with_index do |input, i|
  puts "#{i}: #{input.name}"
end

print "デバイス番号を選択: "
device_num = gets.chomp.to_i

# MIDI入力デバイスを選択
input = UniMIDI::Input.all[device_num]
input.open
puts "選択: #{input.name}"

# ATOM Matrixとのシリアル接続（固定ポート）
serial = UART.open('/dev/cu.usbserial-5D5A501DF0', 115200)
puts "シリアル接続完了: /dev/cu.usbserial-5D5A501DF0"

puts "PC → ATOM Matrix MIDI Bridge 開始"
puts "MIDIデバイスを演奏してください..."

# ポーリングループでMIDI入力をチェック
loop do
  begin
    # ノンブロッキングで連続取得
    loop do
      messages = input.gets
      break unless messages && !messages.empty?
      
      messages.each do |message|
        next unless message && message[:data] && message[:data].length >= 2
        
        # MIDIデータを取得
        midi_bytes = message[:data]
        status = midi_bytes[0]
        
        # 有効なMIDIメッセージかチェック
        case status & 0xF0
        when 0x80..0x8F  # Note Off (3バイト)
          next unless midi_bytes.length >= 3
        when 0x90..0x9F  # Note On (3バイト)
          next unless midi_bytes.length >= 3
        when 0xB0..0xBF  # Control Change (3バイト)
          next unless midi_bytes.length >= 3
        when 0xC0..0xCF  # Program Change (2バイト)
          next unless midi_bytes.length >= 2
        when 0xE0..0xEF  # Pitch Bend (3バイト)
          next unless midi_bytes.length >= 3
        else
          next  # 未対応のメッセージは無視
        end
        
        # ATOM Matrixに転送
        midi_string = midi_bytes.map(&:chr).join
        serial.write(midi_string)
        puts "転送: #{midi_bytes.map{|b| sprintf("%02X", b)}.join(' ')}"
      end
    end
  rescue => e
    puts "MIDIエラー（継続実行）: #{e.message}"
  end
  
  # CPU負荷軽減
  sleep(0.001)  # 1ms待機
end