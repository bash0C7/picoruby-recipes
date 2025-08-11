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
  
  # データ表示
  puts "Accel: X=#{accel[:x].round(3)}, Y=#{accel[:y].round(3)}, Z=#{accel[:z].round(3)} [G]"
  puts "Gyro:  X=#{gyro[:x].round(1)}, Y=#{gyro[:y].round(1)}, Z=#{gyro[:z].round(1)} [deg/s]"
  puts "Temp:  #{temp.round(1)} [C]"
  puts "---"
  
  sleep_ms 500  # 500ms間隔
end