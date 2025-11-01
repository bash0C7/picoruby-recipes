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
led_colors = Array.new(60, 0x0000FF)
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
last_button_state = 1
button_debounce_count = 0
cymbal_trigger = {flag: false}

tick_count = 0
group_history = [1, 1, 1]
saturation = 255
brightness = 51
hue_shift = 0
led_offset = 0

loop do
  tick_count += 1

  current_button = button.read
  if last_button_state == 1 && current_button == 0 && button_debounce_count == 0
    md_uart.write((0x99).chr + 49.chr + (0x7F).chr)
    cymbal_trigger[:flag] = true
    button_debounce_count = 10
  end
  last_button_state = current_button
  button_debounce_count -= 1 if button_debounce_count > 0

  while pc_uart.bytes_available > 0
    uart_data = pc_uart.read(1)
    next unless uart_data && uart_data.length == 1
    cmd_byte = uart_data[0].ord

    case cmd_byte
    when 36..56
      md_uart.write((0x99).chr + cmd_byte.chr + (0x7F).chr)
      g = GT[cmd_byte] || 4
      group_history.shift
      group_history.push(g)
      led_offset = (led_offset + 1) % 60
    when 1..10
      md_uart.write((0xB9).chr + 91.chr + (((cmd_byte - 1) * 127 / 9).to_i).chr)
    when 11..20
      md_uart.write((0xB9).chr + 93.chr + (((cmd_byte - 11) * 127 / 9).to_i).chr)
    end
  end

  if tick_count % 10 == 0
    accel_data = accel_sensor.acceleration
    ax = (accel_data[:x] * 100).to_i
    ay = (accel_data[:y] * 100).to_i
    az = (accel_data[:z] * 100).to_i
    hue_shift = (az.clamp(-100, 100) * 30 / 100).to_i
    brightness = (ax.abs + ay.abs + az.abs) > 80 ? 255 : 51
  end

  if cymbal_trigger[:flag]
    group_history.shift
    group_history.push(5)
    cymbal_trigger[:flag] = false
  end

  if group_history.last == 5
    i = 0
    while i < 60
      led_colors[i] = (led_colors[i] & 0xFF0000) | 0xFFFF
      i += 1
    end
    group_history.pop
    led_strip.show_hsb_hex(*led_colors)
    i = 0
    while i < 60
      led_colors[i] = (led_colors[i] & 0xFF0000) | 0xFF33
      i += 1
    end
  else
    sb = (saturation << 8) | brightness
    group_history.each do |g|
      h = (HUES[g] + hue_shift) << 16 | sb
      case g
      when 1 then 10.times { |s|
        led_colors[(s * 6 + led_offset) % 60] = h
        led_colors[(s * 6 + 1 + led_offset) % 60] = h
        led_colors[(s * 6 + 2 + led_offset) % 60] = h
      }
      when 2 then 10.times { |s|
        led_colors[(s * 6 + 3 + led_offset) % 60] = h
        led_colors[(s * 6 + 4 + led_offset) % 60] = h
        led_colors[(s * 6 + 5 + led_offset) % 60] = h
      }
      when 3 then 12.times { |i| led_colors[(i * 5 + led_offset) % 60] = h }
      when 4 then 6.times { |i| led_colors[(i * 10 + led_offset) % 60] = h }
      end
    end
    led_strip.show_hsb_hex(*led_colors)
  end
  sleep_ms(1)
end
