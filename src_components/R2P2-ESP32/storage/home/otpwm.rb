DEBUG = true  # デバッグモード。true=デバッグ出力、false=デバッグ出力なし
MUTE = false   # PWM消音モード。true=音を出さず数字を表示 false=実際に音を出す

class DPWM
  def initialize(pin, param = {})
    puts "new #{pin}, #{param.to_s}"
    @mute = param[:mute]
  end

  def frequency(f)
    puts "frequency #{f}" if @mute
  end

  def duty(d)
    puts "duty #{d}" if @mute
  end
end

require 'ws2812'
require 'gpio'
require 'irq'
require 'pwm'
require 'i2c'
require 'mpu6886'
require 'vl53l0x'
# require 'iir_filter'  # IIRFilter無効化（速度制限で代替）

class NoiseInstrument
  SPEAKER_PIN = 33
  I2C_SDA_PIN = 25
  I2C_SCL_PIN = 21
  
  DIST_MIN = 20         # 最小距離(mm)。近づくと低い音
  DIST_MAX = 2000       # 最大距離(mm)。遠ざかると高い音
  FREQ_MIN = 100        # 最低周波数(Hz)。ノイズ的な低音
  FREQ_MAX = 2000       # 最高周波数(Hz)。攻撃的な高音
  
  BASE_DUTY = 40           # 基準duty比(%)
  DUTY_MIN = 25            # 最小duty比(%)
  DUTY_MAX = 60            # 最大duty比(%)
  DUTY_DELTA_SCALE = 20    # X軸→duty変化の感度
  
  VIBRATO_SCALE = 50                    # Y軸→ビブラート強さ(Hz)
  CUTOFF_SCALE = 30                     # Z軸→カットオフ風効果(duty微調整)
  
  DUTY_SMOOTH_FACTOR = 1                # duty変化の滑らかさ（即座反応）
  MAX_FREQ_CHANGE_PER_MS = 100          # 周波数変化速度制限(Hz/ms)。素早いグリッサンド

  attr_reader :current_freq, :current_duty
  
  def initialize(speaker, tof_sensor, accel_sensor)
    @speaker = speaker
    @tof_sensor = tof_sensor
    @accel_sensor = accel_sensor
    # @distance_filter = IIRFilter.new  # IIRFilter無効化
    
    @current_freq = FREQ_MIN
    @current_duty = 1
    @target_duty = 1
    
    @freq_range = FREQ_MAX - FREQ_MIN
    @dist_range = DIST_MAX - DIST_MIN
  end
  
  def update_distance
    distance = @tof_sensor.read_distance  # 生の距離値を使用

    # 範囲判定とターゲット周波数計算
    if distance < DIST_MIN
      target_freq = FREQ_MIN
      @target_duty = BASE_DUTY
    elsif distance >= DIST_MIN && distance <= DIST_MAX
      target_freq = FREQ_MIN + (distance - DIST_MIN) * @freq_range / @dist_range
      @target_duty = BASE_DUTY
    else
      # 2000mm超は現在周波数維持、消音
      target_freq = @current_freq
      @target_duty = 1
    end

    # 速度制限（グリッサンド効果）
    freq_diff = target_freq - @current_freq
    if freq_diff > MAX_FREQ_CHANGE_PER_MS
      @current_freq += MAX_FREQ_CHANGE_PER_MS
    elsif freq_diff < -MAX_FREQ_CHANGE_PER_MS
      @current_freq -= MAX_FREQ_CHANGE_PER_MS
    else
      @current_freq = target_freq
    end

    @speaker.frequency(@current_freq)

    puts "D #{distance}, TF #{target_freq}, CF #{@current_freq}" if DEBUG
  end
  
  def update_accel
    accel_data = @accel_sensor.acceleration
    
    vibrato = (accel_data[:y] * VIBRATO_SCALE).to_i
    @speaker.frequency((@current_freq + vibrato).clamp(FREQ_MIN, FREQ_MAX))
    
    duty_delta = (accel_data[:x] * DUTY_DELTA_SCALE).to_i
    cutoff_effect = (accel_data[:z] * CUTOFF_SCALE).to_i
    target_with_effects = (@target_duty + duty_delta + cutoff_effect).clamp(DUTY_MIN, DUTY_MAX)
    
    if @target_duty == 1
      target_with_effects = 1
    end
    
    @current_duty += (target_with_effects - @current_duty) / DUTY_SMOOTH_FACTOR
    @current_duty = @current_duty.clamp(1, DUTY_MAX)
    
    @speaker.duty(@current_duty)
    
    return accel_data
  end
end

class AmbientLEDVisualizer
  LED_PIN = 22
  LED_COUNT = 30
  
  def initialize(led_strip)
    @led_strip = led_strip
    @led_colors = Array.new(LED_COUNT, 0)
    @wave_offset = 0
  end
  
  def update(freq, duty, accel_x, accel_y, accel_z)
    @wave_offset = (@wave_offset + 1) % 384
    
    hue_base = ((freq - NoiseInstrument::FREQ_MIN) * 384 / NoiseInstrument::FREQ_MAX).clamp(0, 384)
    saturation = ((duty - 1) * 255 / NoiseInstrument::DUTY_MAX).clamp(50, 255)
    brightness = ((duty - 1) * 100 / NoiseInstrument::DUTY_MAX).clamp(10, 100)
    
    accel_influence = ((accel_x + accel_y + accel_z) * 50).to_i
    
    LED_COUNT.times do |i|
      hue = (hue_base + @wave_offset + i * 10 + accel_influence) % 384
      sb = (saturation << 8) | brightness
      @led_colors[i] = (hue << 16) | sb
    end
  end
  
  def show
    @led_strip.show_hsb_hex(*@led_colors)
  end
  
  def flash
    @led_strip.flash!(LED_COUNT)
  end
end

speaker = if MUTE
  DPWM.new(NoiseInstrument::SPEAKER_PIN, frequency: 100, duty: 1, mute: MUTE)
else
  PWM.new(NoiseInstrument::SPEAKER_PIN, frequency: 100, duty: 1)
end

button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
led_strip = WS2812.new(RMTDriver.new(AmbientLEDVisualizer::LED_PIN))

i2c_bus = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: NoiseInstrument::I2C_SDA_PIN, scl_pin: NoiseInstrument::I2C_SCL_PIN)
sleep_ms(100)

accel_sensor = MPU6886.new(i2c_bus)
sleep_ms(100)
accel_sensor.accel_range = MPU6886::ACCEL_RANGE_2G
sleep_ms(100)

tof_sensor = VL53L0X.new(i2c_bus)
sleep_ms(100)

instrument = NoiseInstrument.new(speaker, tof_sensor, accel_sensor)
led_viz = AmbientLEDVisualizer.new(led_strip)

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {viz: led_viz}) do |btn, ev, cap|
  cap[:viz].flash
end

loop do
  IRQ.process

  instrument.update_distance
  accel_data = instrument.update_accel

  led_viz.update(instrument.current_freq, instrument.current_duty,
                 accel_data[:x], accel_data[:y], accel_data[:z])
  led_viz.show

  sleep_ms(1)
end

irq.unregister
