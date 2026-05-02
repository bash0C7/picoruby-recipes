# task_debug3.rb — test I2C reads inside a Task
# Hypothesis C: I2C access from Task fails on 2nd+ iteration.
# Wraps each read with rescue so we can see exception class/message.

require 'mpu6886'

class Runner
  attr_accessor :running, :counter, :last_x, :last_err
  def initialize(mpu)
    @mpu = mpu
    @running = true
    @counter = 0
    @last_x = nil
    @last_err = nil
  end

  def loop_method
    while @running
      @counter += 1
      begin
        snap = @mpu.snapshot
        @last_x = snap[:accel][:x]
        x100 = (@last_x * 100).to_i / 100.0
        puts "[task] iter=#{@counter} x=#{x100}"
      rescue => e
        @last_err = "#{e.class}: #{e.message}"
        puts "[task] iter=#{@counter} ERROR #{@last_err}"
      end
      sleep_ms 200
    end
    puts "[task] loop exit"
  end
end

puts "task_debug3 starting"

i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
mpu = MPU6886.new(i2c)
mpu.accel_range = MPU6886::ACCEL_RANGE_4G

runner = Runner.new(mpu)
$__runner = runner

mrb = PicoRubyVM::InstructionSequence.compile(
  '$__runner.loop_method'
).to_binary
task = Task.create(mrb)
raise "task create failed" if task.nil?
task.run
puts "task.run returned"

5.times do |n|
  puts "[main #{n + 1}] counter=#{runner.counter} last_err=#{runner.last_err}"
  sleep_ms 1000
end

runner.running = false
puts "[main] set running=false, joining..."
task.join
puts "main done counter=#{runner.counter}"
