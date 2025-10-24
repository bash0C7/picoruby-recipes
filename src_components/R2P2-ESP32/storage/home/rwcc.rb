require 'uart'

# グローバル変数
$pc = nil      # PC通信用UART
$md = nil      # MIDI音源用UART
$count = 0     # 受信カウンター

# ドラム楽器名マップ（デバッグ用）
DRUM_NAMES = {
  36 => "Kick",
  38 => "Snare",
  39 => "Clap",
  41 => "LowTom",
  42 => "ClHH",
  43 => "LoMidTom",
  45 => "MidTom",
  46 => "OpHH",
  47 => "MidHiTom",
  48 => "HiTom",
  49 => "Crash",
  50 => "HighTom",
  51 => "Ride",
  52 => "China",
  54 => "Tamb",
  56 => "Cowbell"
}

# ハードウェア初期化
def init_hardware
  puts "Init..."
  
  # PC UART初期化（115200bps）
  $pc = UART.new(unit: :ESP32_UART0, baudrate: 115200)
  sleep_ms(50)
  
  # MIDI UART初期化（31250bps = MIDI標準）
  $md = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)
  sleep_ms(50)
  
  # ゴミデータ読み捨て（初回のみ）
  $pc.clear_rx_buffer
  sleep_ms(100)
  
  # 残留データ確認
  if $pc.bytes_available > 0
    garbage = $pc.read($pc.bytes_available)
    puts "Garbage: #{garbage.length}B"
  end
  
  $md.clear_rx_buffer
  sleep_ms(50)
  
  # MIDI音源初期化（Standard Drum Kit = Program 0）
  $md.write((0xC9).chr + (0).chr)  # Program Change Ch10
  sleep_ms(100)
  
  puts "Ready!"
end

# メイン処理ループ
def process_drums
  return unless $pc.bytes_available > 0
  
  # 利用可能な全バイトを処理
  while $pc.bytes_available > 0
    data = $pc.read(1)
    next unless data && data.length == 1
    
    # ドラムノート番号取得
    note = data[0].ord
    
    # 有効範囲チェック（36-56のみ）
    next unless note >= 36 && note <= 56
    
    # MIDI Note On メッセージ生成
    # 0x99 = Note On Channel 10 (ドラム専用チャンネル)
    # note = ドラム番号（36-56）
    # 0x7F = Velocity 127（最大音量）
    midi_msg = (0x99).chr + note.chr + (0x7F).chr
    
    # MIDI音源へ送信
    $md.write(midi_msg)
    
    # デバッグ表示（楽器名付き）
    $count += 1
    name = DRUM_NAMES[note] || "?"
    puts "[#{$count}] #{note}:#{name}"
  end
end

# メイン実行
begin
  init_hardware
  
  puts "=== Drum Receiver ==="
  puts "1Byte Protocol: note(36-56)"
  puts ""
  
  loop_count = 0
  
  loop do
    loop_count += 1
    
    # ドラム処理
    process_drums
    
    # ハートビート（5秒ごと）
    if loop_count % 5000 == 0
      puts "--- Loop: #{loop_count} ---"
    end
    
    sleep_ms(1)  # 1ms待機
  end
  
rescue => e
  puts "Error: #{e.message}"
end
