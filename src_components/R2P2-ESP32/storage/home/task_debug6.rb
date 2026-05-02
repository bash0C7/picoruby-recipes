# task_debug6.rb — test storing Hash returned by self.snapshot into ivar from Task
# debug3 worked storing Float; gem stores Hash. This isolates that one difference.

require 'mpu6886'

class MPU6886
  attr_accessor :_dbg_running, :_dbg_counter, :_dbg_latest

  def _run_dbg_loop_with_hash
    while @_dbg_running
      @_dbg_counter ||= 0
      @_dbg_counter += 1
      @_dbg_latest = self.snapshot   # ← Hash storage from Task
      x = @_dbg_latest[:accel][:x]
      x100 = (x * 100).to_i / 100.0
      puts "[task] counter=#{@_dbg_counter} x=#{x100}"
      sleep_ms 200
    end
    puts "[task] exit"
  end
end

def launch(mpu)
  $__mpu_dbg = mpu
  mrb = PicoRubyVM::InstructionSequence.compile(
    '$__mpu_dbg._run_dbg_loop_with_hash'
  ).to_binary
  task = Task.create(mrb)
  raise "task create failed" if task.nil?
  task.run
  task
end

puts "task_debug6 starting"
i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G
mpu._dbg_running = true
mpu._dbg_counter = 0

task = launch(mpu)
puts "launch returned"

5.times do |n|
  cur = mpu._dbg_latest
  if cur
    cx = (cur[:accel][:x] * 100).to_i / 100.0
    puts "[main #{n + 1}] counter=#{mpu._dbg_counter} cached_x=#{cx}"
  else
    puts "[main #{n + 1}] counter=#{mpu._dbg_counter} cached=nil"
  end
  sleep_ms 1000
end

mpu._dbg_running = false
task.join
puts "done counter=#{mpu._dbg_counter}"
