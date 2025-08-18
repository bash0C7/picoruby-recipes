require 'unimidi'
require 'uart'

puts "デバイスチェック中..."

# 利用可能なMIDIデバイスを取得
midi_devices = UniMIDI::Input.all
if midi_devices.empty?
  puts "エラー: MIDIデバイスが見つかりません"
  exit 1
end

puts "見つかったMIDI入力デバイス:"
midi_devices.each_with_index do |input, i|
  puts "#{i}: #{input.name}"
end

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

puts "\nデバイス確認完了！"

print "\nMIDIデバイス番号を選択: "
midi_device_num = gets.chomp.to_i

if midi_device_num < 0 || midi_device_num >= midi_devices.length
  puts "エラー: 無効なMIDIデバイス番号です"
  exit 1
end

# MIDIデバイスを選択
input = midi_devices[midi_device_num]
input.open
puts "MIDI選択完了: #{input.name}"

print "シリアルデバイス番号を選択: "
serial_device_num = gets.chomp.to_i

if serial_device_num < 0 || serial_device_num >= serial_devices.length
  puts "エラー: 無効なシリアルデバイス番号です"
  exit 1
end

selected_serial_device = serial_devices[serial_device_num]

# ATOM Matrixとのシリアル接続
serial = UART.open(selected_serial_device, 115200)
puts "シリアル選択完了: #{selected_serial_device}"

puts "\nPC → ATOM Matrix MIDI Bridge 開始"
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
