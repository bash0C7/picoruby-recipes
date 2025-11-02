require 'uart'
require 'ws2812'
require 'i2c'
require 'mpu6886'

GT = {36=>1, 38=>2, 39=>3, 49=>5, 52=>5}
HUES = [nil, 0, 128, 192, 64, 0]

pc_uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)
sleep_ms(10)
md_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: 23, rxd_pin: 33)
sleep_ms(10)

led_strip = WS2812.new(RMTDriver.new(22))
led_colors = Array.new(60, 0xC0960A)
sleep_ms(10)

i2c_bus = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
sleep_ms(100)
accel_sensor = MPU6886.new(i2c_bus)
sleep_ms(100)
accel_sensor.accel_range = MPU6886::ACCEL_RANGE_2G
sleep_ms(100)

pc_uart.clear_rx_buffer
md_uart.clear_rx_buffer
md_uart.write((0xC9).chr + (25).chr)

button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
button_debounce_count = 0

tick_count = 0
group_history = [1, 1, 1]
saturation = 255
brightness = 111
led_offset = 0

loop do
  tick_count += 1

  while pc_uart.bytes_available > 0
    uart_data = pc_uart.read(1)
    next unless uart_data && uart_data.length == 1
    cmd_byte = uart_data[0].ord

    case cmd_byte
    when 36..56
      md_uart.write((0x99).chr + cmd_byte.chr + (0x7F).chr)
      g = GT[cmd_byte] || 4
      if g == 5
        puts "FLASH!!"
        led_strip.flash!(led_colors.size)
      else
        group_history.shift
        group_history.push(g)
        led_offset = (led_offset + 1) % led_colors.size
      end
    when 1..10
      md_uart.write((0xB9).chr + 91.chr + (((cmd_byte - 1) * 127 / 9).to_i).chr)
    when 11..20
      md_uart.write((0xB9).chr + 93.chr + (((cmd_byte - 11) * 127 / 9).to_i).chr)
    end
  end

  current_button = button.read
  if current_button == 0 && button_debounce_count == 0
    puts "BUTTON!"
    md_uart.write((0x99).chr + 49.chr + (0x7F).chr)
    led_strip.flash!(led_colors.size)
    button_debounce_count = 50
  end
  button_debounce_count -= 1 if button_debounce_count > 0

  if tick_count % 10 == 0
    accel_data = accel_sensor.acceleration
    ax = (accel_data[:x] * 100).to_i
    ay = (accel_data[:y] * 100).to_i
    az = (accel_data[:z] * 100).to_i
    accel_mag = ax.abs + ay.abs + az.abs
    delta = accel_mag - 100
    saturation = (delta * delta / 20 + 127).clamp(50, 255)
    brightness = ((saturation - 127) * 81 / 128 + 30).clamp(15, 111)
    puts "#{tick_count},#{saturation},#{brightness}"
  end

  sb = (saturation << 8) | brightness
  group_history.each do |g|
    h = HUES[g] << 16 | sb
    case g
    when 1
      10.times { |s|
        led_colors[(s * 6 + led_offset) % led_colors.size] = h
        led_colors[(s * 6 + 1 + led_offset) % led_colors.size] = h
        led_colors[(s * 6 + 2 + led_offset) % led_colors.size] = h
      }
    when 2
      10.times { |s|
        led_colors[(s * 6 + 3 + led_offset) % led_colors.size] = h
        led_colors[(s * 6 + 4 + led_offset) % led_colors.size] = h
        led_colors[(s * 6 + 5 + led_offset) % led_colors.size] = h
      }
    when 3
      12.times { |i| led_colors[(i * 5 + led_offset) % led_colors.size] = h }
    when 4
      6.times { |i| led_colors[(i * 10 + led_offset) % led_colors.size] = h }
    else
      puts "invalid group #{g},#{HUES[g]},#{h}"
    end
  end
  led_strip.show_hsb_hex(*led_colors)
  sleep_ms(1)
end
