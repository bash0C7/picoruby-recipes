# task_debug7.rb — test calling Machine.uptime_us from inside a Task
# debug6 worked but didn't call Machine.*; gem calls it. Isolate that.

class Foo
  attr_accessor :running, :counter, :last_ms
  def initialize
    @running = true
    @counter = 0
    @last_ms = 0
  end
  def loop_method
    while @running
      @counter += 1
      @last_ms = Machine.uptime_us / 1000   # ← target call
      puts "[task] c=#{@counter} ms=#{@last_ms}"
      sleep_ms 200
    end
    puts "[task] exit"
  end
end

def launch(foo)
  $__foo7 = foo
  mrb = PicoRubyVM::InstructionSequence.compile(
    '$__foo7.loop_method'
  ).to_binary
  task = Task.create(mrb)
  raise "task create failed" if task.nil?
  task.run
  task
end

puts "task_debug7 starting"
foo = Foo.new
task = launch(foo)
puts "launch returned"

5.times do |n|
  puts "[main #{n + 1}] c=#{foo.counter} last_ms=#{foo.last_ms}"
  sleep_ms 1000
end

foo.running = false
task.join
puts "done c=#{foo.counter}"
