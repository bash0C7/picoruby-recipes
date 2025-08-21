require 'uart'

def flash_keyboard_backlight(duration: 3)
  # バックライトを最大にする
  system("osascript -e 'tell application \"System Events\" to repeat 16 times
    key code 113
    delay 0.01
  end repeat'")
  
  sleep(duration)
  
  # バックライトを消灯する
  system("osascript -e 'tell application \"System Events\" to repeat 20 times
    key code 107
    delay 0.01
  end repeat'")
  
end

# メイン処理
str = (ARGV.first || "b").downcase
serial_devices = Dir.glob('/dev/cu.usbserial*')

if serial_devices.any?
  begin
    serial = UART.open(serial_devices.first, 115200)
    serial.write str
    serial.close
  rescue => e
    flash_keyboard_backlight
  end
else
  flash_keyboard_backlight
end