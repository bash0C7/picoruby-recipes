# task_debug11.rb — gem pattern + Task.pass instead of puts
# Tests whether an explicit Task.pass between snapshot and sleep_ms is
# enough to prevent the Task from being killed/starved.

require 'mpu6886'

class MPU6886
  attr_accessor :_dbg11_running, :_dbg11_count

  def _run_dbg11
    while @_dbg11_running
      @_dbg11_count ||= 0
      @_dbg11_count += 1
      @_dbg11_latest = self.snapshot
      Task.pass
      sleep_ms(20)
    end
  end
end

def launch11(mpu)
  $__mpu_dbg11 = mpu
  mrb = PicoRubyVM::InstructionSequence.compile(
    '$__mpu_dbg11._run_dbg11'
  ).to_binary
  task = Task.create(mrb)
  raise "task11 create failed" if task.nil?
  task.run
  task
end

puts "task_debug11 starting"
i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G
mpu._dbg11_running = true

task = launch11(mpu)
puts "launch11 returned"

5.times do |n|
  puts "[main #{n + 1}] count=#{mpu._dbg11_count}"
  sleep_ms 1000
end

mpu._dbg11_running = false
task.join
puts "done count=#{mpu._dbg11_count}"
