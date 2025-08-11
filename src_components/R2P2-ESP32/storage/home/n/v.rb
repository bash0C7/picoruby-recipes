require 'i2c'

i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 26, scl_pin: 32)
address = 0x29

puts "=== 手動測定テスト ==="

# 基本初期化
i2c.write(address, 0x80, 0x01, timeout: 2000)
i2c.write(address, 0xFF, 0x01, timeout: 2000)
i2c.write(address, 0x00, 0x00, timeout: 2000)
stop_variable_data = i2c.read(address, 1, 0x91, timeout: 1000)
stop_variable = stop_variable_data.bytes[0]
i2c.write(address, 0x00, 0x01, timeout: 2000)
i2c.write(address, 0xFF, 0x00, timeout: 2000)
i2c.write(address, 0x80, 0x00, timeout: 2000)

puts "初期化完了"

# 5回測定テスト
5.times do |i|
  puts "測定 #{i+1}:"
  
  # 測定開始
  i2c.write(address, 0x00, 0x01, timeout: 2000)
  puts "  測定開始"
  
  # 測定完了待ち
  timeout = 0
  loop do
    status_data = i2c.read(address, 1, 0x13, timeout: 1000)
    status = status_data.bytes[0]
    break if (status & 0x07) != 0
    
    timeout += 1
    if timeout > 1000
      puts "  タイムアウト"
      break
    end
    sleep(0.001)
  end
  
  puts "  測定完了 (timeout: #{timeout})"
  
  # 距離読み取り（両方のレジスタ）
  data14 = i2c.read(address, 2, 0x14, timeout: 1000)
  bytes14 = data14.bytes
  distance14 = (bytes14[0] << 8) | bytes14[1]
  
  data1e = i2c.read(address, 2, 0x1E, timeout: 1000)
  bytes1e = data1e.bytes
  distance1e = (bytes1e[0] << 8) | bytes1e[1]
  
  puts "  0x14: #{distance14}mm"
  puts "  0x1E: #{distance1e}mm"
  
  # 割り込みクリア
  i2c.write(address, 0x0B, 0x01, timeout: 2000)
  
  sleep(1)
end
