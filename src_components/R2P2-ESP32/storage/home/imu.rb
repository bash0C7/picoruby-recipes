# MPU6886 IMU Sensor Data Display
# Simple sensor value monitoring program
# Built-in IMU connected to I2C (SDA:25, SCL:21)

require 'mpu6886'

puts "MPU6886 IMU Sensor Starting..."

# I2C初期化
i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G
mpu.gyro_range = MPU6886::GYRO_RANGE_2000DPS

puts "MPU6886 initialized (4G accel, 2000DPS gyro)"
puts "---"

# センサーデータ連続表示
loop do
  # 加速度取得
  accel = mpu.acceleration
  
  # ジャイロスコープ取得
  gyro = mpu.gyroscope
  
  # 温度取得
  temp = mpu.temperature
  
  # データ表示（手動丸め処理）
  puts "Accel: X=#{(accel[:x] * 1000).to_i / 1000.0}, Y=#{(accel[:y] * 1000).to_i / 1000.0}, Z=#{(accel[:z] * 1000).to_i / 1000.0} [G]"
  puts "Gyro:  X=#{(gyro[:x] * 10).to_i / 10.0}, Y=#{(gyro[:y] * 10).to_i / 10.0}, Z=#{(gyro[:z] * 10).to_i / 10.0} [deg/s]"
  puts "Temp:  #{(temp * 10).to_i / 10.0} [C]"
  puts "---"
  
  sleep_ms 500  # 500ms間隔
end