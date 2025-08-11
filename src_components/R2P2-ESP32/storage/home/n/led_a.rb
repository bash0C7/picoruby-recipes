require 'ws2812'
require 'uart'

# ATOM Matrix + Unit ASR 簡素版
# hello / ok のみ対応

# 設定
LED_COUNT = 25
LED_PIN = 27
# ATOM MatrixのGroveポート: SDA=26, SCL=32（通常はI2C）
# でもUART使用時はTX/RXとして使用可能
UART_TX = 26  # Grove SDA → UART TX  
UART_RX = 32  # Grove SCL → UART RX

# 初期化
uart = UART.new(unit: :ESP32_UART1, baudrate: 115200, txd_pin: UART_TX, rxd_pin: UART_RX)
led = WS2812.new(RMTDriver.new(LED_PIN))
colors = Array.new(LED_COUNT) { [0, 0, 10] }  # 初期：暗い青

# 色定義（20%輝度）
color_hello = [51, 25, 0]     # オレンジ - "hello"
color_ok = [0, 25, 51]        # シアン - "ok" 
color_standby = [0, 0, 10]    # 暗い青

# 現在の色
current_color = color_standby

# Unit ASR初期化
puts "UART初期化完了"
uart.write("\xAA\x55\xB1\x05")
sleep_ms(500)
puts "Unit ASR 準備完了"

puts "LED初期化開始..."
# 初期表示
LED_COUNT.times { |i| colors[i] = current_color }
puts "色配列設定完了"

led.show_rgb(*colors)
puts "LED表示完了"

puts "メインループ開始"

# メインループ
loop_count = 0
puts "メインループ開始"

loop do
  loop_count += 1
  if loop_count % 20 == 0  # 20回に1回状況表示（頻繁に）
    puts "ループ: #{loop_count}"
  end
  
  # UART受信確認（メモリ効率重視・簡素版）
  if uart.bytes_available >= 5
    puts "データ受信"
    
    # 5バイト一括読み取り（シンプル）
    data = uart.read(5)
    
    if data && data.length == 5 &&
       data[0].ord == 0xAA && data[1].ord == 0x55 &&
       data[3].ord == 0x55 && data[4].ord == 0xAA
      
      cmd = data[2].ord
      puts "コマンド認識"
      
      if cmd == 0x32  # hello
        puts "hello"
        current_color = color_hello
        LED_COUNT.times { |i| colors[i] = current_color }
        led.show_rgb(*colors)
      elsif cmd == 0x30  # ok
        puts "ok"
        current_color = color_ok
        LED_COUNT.times { |i| colors[i] = current_color }
        led.show_rgb(*colors)
      end
    end
  end
  
  sleep_ms(50)
end
