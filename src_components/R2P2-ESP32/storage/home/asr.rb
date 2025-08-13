# Unit ASR Voice Recognition - "open" command detection
# CI-03T AI voice recognition module

# https://docs.m5stack.com/ja/unit/Unit%20ASR

# ATOM Matrix + Unit ASR 簡素版

require 'ws2812'
require 'uart'

# 設定
LED_COUNT = 25
LED_PIN = 27
UART_TX = 26
UART_RX = 32

# 初期化
led = WS2812.new(RMTDriver.new(LED_PIN))
uart = UART.new(unit: :ESP32_UART1, baudrate: 115200, txd_pin: UART_TX, rxd_pin: UART_RX)

puts "UART初期化完了"
sleep_ms(100)  # ハードウェア安定化待ち

# Unit ASR起動完了を待つ（Arduino版に合わせる）
puts "Unit ASR起動待ち..."
sleep_ms(3000)  # 3秒待機（モジュール起動時間）
uart.clear_rx_buffer()  # 起動時のノイズも削除
puts "Unit ASR準備完了"

# 色定義
COLOR_HELLO = [51, 25, 0]    # オレンジ
COLOR_OK = [0, 25, 51]       # シアン  
COLOR_STANDBY = [0, 0, 10]   # 暗い青

current_colors = Array.new(LED_COUNT) { COLOR_STANDBY.dup }
led.show_rgb(*current_colors)

# 受信バッファ（シンプル配列）
rx_buffer = []

puts "初期化完了"
puts "*** 使用方法 ***"
puts "1. 'Hi M Five' と言ってウェイクアップ"
puts "2. 'hello' または 'ok' でコマンド実行"

# LED更新関数
def update_leds(led, current_colors, new_color)
  LED_COUNT.times { |i| current_colors[i] = new_color.dup }
  led.show_rgb(*current_colors)
end

# バッファからパケット検出（C++ロジック移植）
def find_and_parse_packet(buffer)
  return nil if buffer.length < 5
  
  # ヘッダー0xAA 0x55を探す（1バイトずつスライド）
  i = 0
  while i <= buffer.length - 5
    if buffer[i] == 0xAA && buffer[i + 1] == 0x55
      # ヘッダー発見！フッターもチェック
      if buffer[i + 3] == 0x55 && buffer[i + 4] == 0xAA
        # 完全なパケット発見
        cmd = buffer[i + 2]
        
        # 処理済みデータを削除（パケット部分）
        (i + 5).times { buffer.shift }
        
        return cmd
      end
    end
    i += 1
  end
  
  # ヘッダーが見つからない場合、最初の方を削除（メモリ節約）
  if buffer.length > 10
    5.times { buffer.shift }
  end
  
  return nil
end

# UART受信処理
def receive_data(uart, buffer)
  # 利用可能なバイトを全て読む（バースト受信対応）
  while uart.bytes_available > 0
    data = uart.read(1)
    if data && data.length == 1
      buffer.push(data[0].ord)
    end
    
    # バッファサイズ制限（メモリ保護）
    if buffer.length > 20
      buffer.shift
    end
  end
end

# メインループ
loop_count = 0

loop do
  loop_count += 1
  
  # UART受信
  receive_data(uart, rx_buffer)
  
  # パケット解析
  cmd = find_and_parse_packet(rx_buffer)
  
  if cmd
    case cmd
    when 0x32  # hello
      puts "hello"
      update_leds(led, current_colors, COLOR_HELLO)
    when 0x30  # ok  
      puts "ok"
      update_leds(led, current_colors, COLOR_OK)
    else
      puts "未知: 0x#{cmd.to_s(16)}"
    end
  end
  
  # デバッグ出力（頻度削減）
  if loop_count % 1000 == 0
    puts "ループ: #{loop_count}, バッファ: #{rx_buffer.length}"
  end
  
  sleep_ms(10)  # 高頻度チェック
end
