# task_debug10.rb — gem pattern + a single minimal puts (no other ops)
# Bisects whether `puts` itself is the magic that keeps the Task alive.

require 'mpu6886'

class MPU6886
  attr_accessor :_dbg10_running, :_dbg10_count

  def _run_dbg10
    while @_dbg10_running
      @_dbg10_count ||= 0
      @_dbg10_count += 1
      @_dbg10_latest = self.snapshot
      puts "."
      sleep_ms(20)
    end
  end
end

def launch10(mpu)
  $__mpu_dbg10 = mpu
  mrb = PicoRubyVM::InstructionSequence.compile(
    '$__mpu_dbg10._run_dbg10'
  ).to_binary
  task = Task.create(mrb)
  raise "task10 create failed" if task.nil?
  task.run
  task
end

puts "task_debug10 starting"
i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G
mpu._dbg10_running = true

task = launch10(mpu)
puts "launch10 returned"

5.times do |n|
  puts "[main #{n + 1}] count=#{mpu._dbg10_count}"
  sleep_ms 1000
end

mpu._dbg10_running = false
task.join
puts "done count=#{mpu._dbg10_count}"
