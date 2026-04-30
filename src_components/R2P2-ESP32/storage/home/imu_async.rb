# imu_async.rb — background sampler verification
# Verifies start_sampling spawns a Task that keeps latest_acceleration fresh
# while the main loop does unrelated work.
require 'mpu6886'

puts "MPU6886 async sampler test"

i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G
mpu.gyro_range  = MPU6886::GYRO_RANGE_2000DPS

mpu.start_sampling(interval_ms: 20)   # 50Hz background

ticks = 0
loop do
  ticks += 1
  accel = mpu.latest_acceleration
  if accel
    ax = (accel[:x] * 100).to_i / 100.0
    ay = (accel[:y] * 100).to_i / 100.0
    az = (accel[:z] * 100).to_i / 100.0
    puts "[main #{ticks}] cached accel: X=#{ax} Y=#{ay} Z=#{az}"
  else
    puts "[main #{ticks}] no sample yet"
  end

  # Main loop intentionally slower than sampler interval (20ms).
  # Samples must keep arriving from the background Task.
  sleep_ms 500

  break if ticks >= 10
end

mpu.stop_sampling
puts "stopped"
