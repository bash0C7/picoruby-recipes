# https://claude.ai/chat/de566203-6a66-4278-ae6f-b1638205b3d6
# Unit ASR Voice Recognition Module for PicoRuby
# CI-03T AI voice recognition module wrapper class

class UnitASR
  # 内部設定
  BUFFER_MAX_SIZE = 20
  STARTUP_DELAY_MS = 3000
  WAKEUP_CMD = 0xFF
  
  def initialize(uart)
    @uart = uart
    @rx_buffer = []
    @command_handlers = {}
    @unknown_handler = Proc.new { |cmd_num| }  # 空のブロック（デフォルト）
    @current_command_num = nil
    @is_awake = false
    
    initialize_module
  end
  
  # コマンドハンドラー登録 (Command Num指定)
  def add_handler(cmd_num, &block)
    @command_handlers[cmd_num] = block
  end
  
  # 未登録コマンド用ハンドラー設定
  def set_unknown_handler(&block)
    @unknown_handler = block
  end
  
  # メインループ更新処理
  def update
    receive_data
    parse_packets
  end
  
  # 現在認識されたコマンド番号
  def current_command_num
    @current_command_num
  end
  
  # ウェイクアップ状態確認
  def awake?
    @is_awake
  end
  
  # デバッグ情報
  def buffer_size
    @rx_buffer.length
  end
  
  private
  
  # モジュール初期化
  def initialize_module
    puts "Unit ASR初期化中..."
    sleep_ms(100)
    
    puts "起動待ち..."
    sleep_ms(STARTUP_DELAY_MS)
    
    @uart.clear_rx_buffer if @uart.respond_to?(:clear_rx_buffer)
    puts "Unit ASR準備完了"
  end
  
  # UART受信処理
  def receive_data
    while @uart.bytes_available > 0
      data = @uart.read(1)
      if data && data.length == 1
        @rx_buffer.push(data[0].ord)
      end
      
      if @rx_buffer.length > BUFFER_MAX_SIZE
        @rx_buffer.shift
      end
    end
  end
  
  # パケット解析処理
  def parse_packets
    cmd = find_and_parse_packet
    
    if cmd
      @current_command_num = cmd
      handle_command(cmd)
    end
  end
  
  # パケット検出
  def find_and_parse_packet
    return nil if @rx_buffer.length < 5
    
    i = 0
    while i <= @rx_buffer.length - 5
      if @rx_buffer[i] == 0xAA && @rx_buffer[i + 1] == 0x55
        if @rx_buffer[i + 3] == 0x55 && @rx_buffer[i + 4] == 0xAA
          cmd = @rx_buffer[i + 2]
          (i + 5).times { @rx_buffer.shift }
          return cmd
        end
      end
      i += 1
    end
    
    if @rx_buffer.length > 10
      5.times { @rx_buffer.shift }
    end
    
    nil
  end
  
  # コマンド処理
  def handle_command(cmd)
    if cmd == WAKEUP_CMD
      @is_awake = true
    end
    
    # ハンドラー実行（分岐なし）
    if @command_handlers[cmd]
      @command_handlers[cmd].call
    else
      @unknown_handler.call(cmd)
    end
  end
end

require 'uart'

# 設定
UART_TX = 26
UART_RX = 32

# ハードウェア初期化
uart = UART.new(unit: :ESP32_UART1, baudrate: 115200, txd_pin: UART_TX, rxd_pin: UART_RX)

# Unit ASR初期化
asr = UnitASR.new(uart)

# コマンドハンドラー登録
asr.add_handler(0x32) do  # "hello"
  puts "ハロー!"
end

asr.add_handler(0x30) do  # "ok"
  puts "オーケー!"
end

# 未登録コマンド用ハンドラー（デバッグ用）
asr.set_unknown_handler do |cmd_num|
  puts "未登録コマンド: 0x#{cmd_num.to_s(16)}"
end

puts "=== Unit ASR デモ開始 ==="
puts "音声コマンド:"
puts "- 'Hi M Five' : ウェイクアップ"  
puts "- 'hello'     : オレンジ点灯"
puts "- 'ok'        : シアン点灯"

# メインループ
loop_count = 0

loop do
  loop_count += 1
  
  # Unit ASR更新（重要！）
  asr.update
  
  # デバッグ情報表示
  if loop_count % 500 == 0
    puts "ループ: #{loop_count}, バッファ: #{asr.buffer_size}, 覚醒: #{asr.awake?}"
  end
  
  sleep_ms(10)
end
