require 'ws2812'
require 'uart'

def chika_animation(cnt, pin)
  led = WS2812.new(RMTDriver.new(pin))
  uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)
  
  # メモリ効率化：色配列を一度だけ確保
  colors = Array.new(cnt)
  cnt.times { |i| colors[i] = [0, 0, 0] }

  # フラット化：ネストを避ける状態管理
  animation_state = :idle
  animation_frame = 0
  target_color = [0, 0, 0]
  max_frames = 25
  
  loop do
    # 入力処理（ネストなし）
    input = uart.read
    if input && input.length > 0
      puts input
      
      animation_state = case input
      when "r" 
        uart.puts "R"
        target_color = [100, 20, 0]
        :animating
      when "g"
        uart.puts "G" 
        target_color = [20, 100, 0]
        :animating
      when "b"
        uart.puts "B"
        target_color = [0, 20, 100]
        :animating
      else 
        :idle
      end
      animation_frame = 0
    end
    
    # アニメーション処理（ネストなし）
    if animation_state == :animating
      brightness = animation_frame * 100 / max_frames
      
      # each避けてindexアクセスでスタック節約
      cnt.times do |i|
        colors[i][0] = target_color[0] * brightness / 100
        colors[i][1] = target_color[1] * brightness / 100  
        colors[i][2] = target_color[2] * brightness / 100
      end
      
      led.show_rgb(*colors)
      animation_frame += 1
      
      # アニメーション完了チェック
      if animation_frame >= max_frames
        animation_state = :fadeout
        animation_frame = 0
      end
      
    elsif animation_state == :fadeout
      # フェードアウト処理
      brightness = 100 - (animation_frame * 100 / 10)
      
      cnt.times do |i|
        colors[i][0] = target_color[0] * brightness / 100
        colors[i][1] = target_color[1] * brightness / 100
        colors[i][2] = target_color[2] * brightness / 100
      end
      
      led.show_rgb(*colors)
      animation_frame += 1
      
      if animation_frame >= 10
        animation_state = :idle
        # 完全消灯
        cnt.times { |i| colors[i] = [0, 0, 0] }
        led.show_rgb(*colors)
      end
    end
    
    # 固定間隔でCPU負荷軽減
    sleep_ms(100)
  end
end

arg_cnt = ARGV[0] || 25
puts arg_cnt
arg_pin = ARGV[1] || 27
puts arg_pin
chika_animation(arg_cnt.to_i, arg_pin.to_i)