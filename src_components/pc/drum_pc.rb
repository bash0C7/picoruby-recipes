require 'uart'
require 'io/console'

puts "=== PicoRuby Finger Drum - PC Keyboard Version ==="
puts "キーボード → UART → ATOM Matrix → MIDI Unit にょん！"

# DECK構造のキーマッピング
key_notes = {
  # ===== DECK1 =====
  # PAD 1-4
  'a' => 36,  # DECK1 PAD1: Kick (Bass Drum)
  's' => 38,  # DECK1 PAD2: Snare
  'd' => 42,  # DECK1 PAD3: Closed Hi-Hat
  'f' => 46,  # DECK1 PAD4: Open Hi-Hat

  # PAD 5-8
  'z' => 49,  # DECK1 PAD5: Crash Cymbal
  'x' => 51,  # DECK1 PAD6: Ride Cymbal
  'c' => 39,  # DECK1 PAD7: Hand Clap
  'v' => 56,  # DECK1 PAD8: Cowbell

  # ===== DECK2 =====
  # PAD 1-4
  'g' => 41,  # DECK2 PAD1: Low Tom
  'h' => 43,  # DECK2 PAD2: Low-Mid Tom
  'j' => 45,  # DECK2 PAD3: Mid Tom
  'k' => 47,  # DECK2 PAD4: Mid-Hi Tom

  # PAD 5-8
  'b' => 48,  # DECK2 PAD5: Hi Tom
  'n' => 50,  # DECK2 PAD6: High Tom
  'm' => 54,  # DECK2 PAD7: Tambourine
  ',' => 52   # DECK2 PAD8: Chinese Cymbal
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

puts "\n=== フィンガードラムモード開始 ==="
puts "【DECK1 上段（a,s,d,f）】"
puts "  a: Kick  s: Snare  d: Closed HH  f: Open HH"
puts ""
puts "【DECK1 下段（z,x,c,v）】"
puts "  z: Crash  x: Ride  c: Clap  v: Cowbell"
puts ""
puts "【DECK2 上段（g,h,j,k）】"
puts "  g: Low Tom  h: Low-Mid Tom  j: Mid Tom  k: Mid-Hi Tom"
puts ""
puts "【DECK2 下段（b,n,m,）】"
puts "  b: Hi Tom  n: High Tom  m: Tambourine  ,: Chinese Cymbal"
puts ""
puts "同時押し対応！ a+z で キック+クラッシュ等、複数キーを同時に叩けますにょん！"
puts "q キーで終了\n"
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

        # q キーで終了
        if key == 'q'
          print "\r\nアディオス！にょん！\r\n"
          exit 0
        end

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
          # Protocol v2: ドラムノート番号のみ送信（1byte）
          serial.write(note.chr)
        end

        # デバッグ表示（\r\nで改行を明示的に指定）
        keys_str = keys_pressed.map(&:upcase).join('+')
        notes_str = keys_pressed.map { |k| key_notes[k] }.join('+')
        print "♪ #{keys_str} → #{notes_str}\r\n"
      end
    end
  end

rescue Interrupt
  print "\r\nプロセス中断にょん！\r\n"
  exit 0
rescue => e
  print "\r\nエラー: #{e.message}\r\n"
  exit 1
end
