require 'i2c'
i2c = I2C.new(unit: "ESP32_I2C0", frequency: 100_000, sda_pin: 25, scl_pin: 21)
[0x38, 0x39, 0x14, 0x70, 0x54, 0x6c].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }
[0x38, 0x0c, 0x01].each { |i| i2c.write(0x3e, 0, i); sleep_ms 1 }
"Hello,".bytes.each { |c| i2c.write(0x3e, 0x40, c); sleep_ms 1 }
i2c.write(0x3e, 0, 0x80|0x40)
"ESP32!".bytes.each { |c| i2c.write(0x3e, 0x40, c); sleep_ms 1 }
