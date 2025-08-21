# Claude Code Hook通知プログラム
# 目的: Claude Codeのフック実行時にユーザーに視覚的な通知を提供
# 動作: シリアルデバイス（/dev/cu.usbserial*）が利用可能であれば通信を試行、
#       失敗またはデバイスがない場合はMac単体でなんらか通知する
# 使用: Claude Code設定でフックプログラムとして設定
require 'uart'

def flash_notification(duration: 3)
  # Mac通知を表示
  system("osascript -e 'display notification \"Claude Code実行完了\" with title \"Claude Code Hook\" sound name \"Glass\"'")
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
    flash_notification
  end
else
  flash_notification
end