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

# MIDI ドラムキット定義
DRUM_KITS = {
  0 => "Standard Drum Kit",
  8 => "Room Drum Kit",
  16 => "Power Drum Kit",
  24 => "Electronic Drum Kit",
  25 => "TR-808 Drum Kit",
  32 => "Jazz Drum Kit"
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
  
  # ゴミデータ読み捨て
  $pc.clear_rx_buffer
  sleep_ms(100)
  
  # 残留データ確認
  if $pc.bytes_available > 0
    garbage = $pc.read($pc.bytes_available)
    puts "Garbage: #{garbage.length}B"
  end
  
  $md.clear_rx_buffer
  sleep_ms(50)
  
  # MIDI音源初期化（TR-808 Drum Kit = Program 25）
  $md.write((0xC9).chr + (25).chr)  # Program Change Ch10
  sleep_ms(100)
  
  puts "Ready!"
end

# MIDI CC送信（コーラスとリバーブ用）
def send_midi_cc(cc_num, value)
  # 0xB9 = Control Change Channel 10 (ドラムチャンネル)
  midi_msg = (0xB9).chr + cc_num.chr + value.chr
  $md.write(midi_msg)
end

# メイン処理ループ
def process_commands
  return unless $pc.bytes_available > 0
  
  # 利用可能な全バイトを処理
  while $pc.bytes_available > 0
    data = $pc.read(1)
    next unless data && data.length == 1
    
    # コマンドバイト取得
    cmd = data[0].ord
    
    # コマンド種別判定
    case cmd
    when 36..56
      # ドラムノート（36-56）
      process_drum_note(cmd)
      
    when 1..10
      # 残響レベル（1-10 → 0-9）
      process_reverb(cmd)
      
    when 11..20
      # コーラスレベル（11-20 → 0-9）
      process_chorus(cmd)
      
    else
      # 範囲外は無視
    end
  end
end

# ドラムノート処理
def process_drum_note(note)
  # MIDI Note On メッセージ生成
  # 0x99 = Note On Channel 10 (ドラム専用チャンネル)
  midi_msg = (0x99).chr + note.chr + (0x7F).chr
  $md.write(midi_msg)
  
  # デバッグ表示
  $count += 1
  name = DRUM_NAMES[note] || "?"
  puts "[#{$count}] 🥁 #{note}:#{name}"
end

# 残響（リバーブ）処理
def process_reverb(level_cmd)
  # 1-10 → 0-9
  level = level_cmd - 1
  
  # 0-9 → 0-127にマッピング
  cc_value = (level * 127 / 9).to_i
  cc_value = 127 if cc_value > 127
  
  # MIDI CC#91 (Reverb Send Level)
  send_midi_cc(91, cc_value)
  
  # デバッグ表示
  $count += 1
  puts "[#{$count}] 🌊 REVERB: #{level} → CC#{cc_value}"
end

# コーラス処理
def process_chorus(level_cmd)
  # 11-20 → 0-9
  level = level_cmd - 11

  # 0-9 → 0-127にマッピング
  cc_value = (level * 127 / 9).to_i
  cc_value = 127 if cc_value > 127

  # MIDI CC#93 (Chorus Send Level)
  send_midi_cc(93, cc_value)

  # デバッグ表示
  $count += 1
  puts "[#{$count}] 🎵 CHORUS: #{level} → CC#{cc_value}"
end

# メイン実行
begin
  init_hardware
  
  puts "=== Enhanced Drum Receiver にょん！==="
  puts "Drum Kit: #{DRUM_KITS[25]}"
  puts "Protocol v2:"
  puts "  36-56  : Drum Notes"
  puts "  1-10   : Reverb (CC#91)"
  puts "  11-20  : Chorus (CC#93)"
  puts ""
  
  loop_count = 0
  
  loop do
    loop_count += 1
    
    # コマンド処理
    process_commands
    
    # ハートビート（10秒ごと）
    if loop_count % 10000 == 0
      puts "--- Loop: #{loop_count} ---"
    end
    
    sleep_ms(1)  # 1ms待機
  end
  
rescue => e
  puts "Error: #{e.message}"
end
