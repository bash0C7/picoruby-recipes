# tof_async.rb — background Task sampler verification
# Verifies start_sampling spawns a Task that keeps latest_distance fresh
# while the main loop does unrelated work.
# VL53L0X connected to J3 (SDA:25, SCL:21)

require 'i2c'
require 'vl53l0x'

puts "VL53L0X async sampler test"
puts "J3: SDA=25, SCL=21"

# I2C初期化
i2c = I2C.new(
  unit: :ESP32_I2C0,
  frequency: 100_000,
  sda_pin: 25,
  scl_pin: 21,
  timeout: 2000
)

vl53l0x = VL53L0X.new(i2c)

unless vl53l0x.ready?
  puts "Failed to initialize VL53L0X"
  exit
end

puts "VL53L0X initialized"

# backgroundサンプラー起動 (33ms = デフォルト間隔)
vl53l0x.start_sampling(interval_ms: 33)
puts "start_sampling done (33ms interval, background Task running)"
puts "Main loop: 500ms - much slower than sampler interval"
puts "---"

# メインループ
ticks = 0
loop do
  ticks += 1
  dist = vl53l0x.latest_distance

  if dist
    if dist > 0
      puts "[main #{ticks}] cached distance: #{dist}mm"
    else
      puts "[main #{ticks}] out of range or error"
    end
  else
    puts "[main #{ticks}] no sample yet (fresh?=#{vl53l0x.fresh?})"
  end

  # メインループ意図的に遅くする - サンプラーはバックグラウンドで動き続ける
  sleep_ms 500

  break if ticks >= 10
end

vl53l0x.stop_sampling
puts "---"
puts "stop_sampling done"
