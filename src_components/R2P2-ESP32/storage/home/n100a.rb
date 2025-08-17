
# ATOM Matrix外付けLED光源ペンライト
class UnitASR
  BUFFER_MAX_SIZE = 20
  STARTUP_DELAY_MS = 3000
  WAKEUP_CMD = 0xFF
  
  def initialize(uart)
    @uart = uart
    @rx_buffer = []
    @command_handlers = {}
    @unknown_handler = Proc.new { |cmd_num| } 
    @current_command_num = nil
    @is_awake = false
    
    initialize_module
  end
  
  def add_handler(cmd_num, &block)
    @command_handlers[cmd_num] = block
  end
  
  def set_unknown_handler(&block)
    @unknown_handler = block
  end
  
  def update
    receive_data
    parse_packets
  end
  
  def current_command_num
    @current_command_num
  end
  
  def awake?
    @is_awake
  end
  
  def buffer_size
    @rx_buffer.length
  end
  
  private
  
  def initialize_module
    sleep_ms(100)
    sleep_ms(STARTUP_DELAY_MS)
    @uart.clear_rx_buffer if @uart.respond_to?(:clear_rx_buffer)
  end
  
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
  
  def parse_packets
    cmd = find_and_parse_packet
    
    if cmd
      @current_command_num = cmd
      handle_command(cmd)
    end
  end
  
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
  
  def handle_command(cmd)
    if cmd == WAKEUP_CMD
      @is_awake = true
    end
    
    if @command_handlers[cmd]
      @command_handlers[cmd].call
    else
      @unknown_handler.call(cmd)
    end
  end
end

require 'ws2812'

led_pin = 22
led_count = 90

led = WS2812.new(RMTDriver.new(led_pin))

orange_r = 200
orange_g = 100
orange_b = 0
colors = Array.new(led_count) { [orange_r, orange_g, orange_b] }

require 'uart'

UART_TX = 26
UART_RX = 32

asr = UnitASR.new(UART.new(unit: :ESP32_UART1, baudrate: 115200, txd_pin: UART_TX, rxd_pin: UART_RX))

# コマンドハンドラー登録
asr.add_handler(0x17) do  # "pause"
  orange_r = 20
  orange_g = 10
  orange_b = 0
end

asr.add_handler(0x30) do  # "ok"
  orange_r = 100
  orange_g = 50
  orange_b = 0
end

asr.add_handler(0x10) do  # "open"
  orange_r = 220
  orange_g = 140
  orange_b = 0
end

loop do
  #Hi M Five, pause, ok, open
  asr.update
  
  led_count.times do |i|
    colors[i] = [orange_r, orange_g, orange_b]
  end
  
  led.show_rgb(*colors)
  
  sleep_ms 100
end
