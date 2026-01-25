DEBUG = true  # デバッグモード。true=デバッグ出力、false=デバッグ出力なし
MUTE = false   # PWM消音モード。true=音を出さず数字を表示 false=実際に音を出す
NOISE_MODE = true  # ノイズ音モード。true=ノイズ音、false=通常BEEP音

module Speaker
  def frequency(f)
    set_frequency(f)
  end

  def duty(d)
    set_duty(d)
  end

  protected

  def set_frequency(f)
    # サブクラスで実装
  end

  def set_duty(d)
    # サブクラスで実装
  end
end

class DPWM
  include Speaker

  def initialize(pin, param = {})
    puts "new #{pin}, #{param.to_s}"
    @mute = param[:mute]
  end

  protected

  def set_frequency(f)
    puts "frequency #{f}" if @mute
  end

  def set_duty(d)
    puts "duty #{d}" if @mute
  end
end

class SimplePWM
  include Speaker

  def initialize(pin, param = {})
    @pwm = PWM.new(pin, param)
  end

  protected

  def set_frequency(f)
    @pwm.frequency(f)
  end

  def set_duty(d)
    @pwm.duty(d)
  end
end

class SimpleRandom
  # 線形合同法（LCG）による擬似乱数生成
  # next = (a * seed + c) % m
  # パラメータ: a=1103515245, c=12345, m=2^31

  def initialize(seed = 12345)
    @seed = seed
  end

  def next_int
    @seed = (@seed * 1103515245 + 12345) & 0x7FFFFFFF
    @seed
  end

  def rand(max)
    (self.next_int % max)
  end
end

class NoisyPWM
  include Speaker

  # ホワイトノイズ実装：周波数は基本周波数にほぼ固定、デューティ比をランダムに変動
  FREQ_STABLE_RANGE = 5  # 周波数微調整(Hz)。基本周波数を維持

  def initialize(pin, param = {})
    @pwm = PWM.new(pin, param)
    @random = SimpleRandom.new
    @base_freq = param[:frequency] || 100
    @base_duty = param[:duty] || 1
  end

  protected

  def set_frequency(f)
    @base_freq = f
    # 周波数は基本周波数にほぼ固定（微調整のみ）
    noise = @random.rand(FREQ_STABLE_RANGE) - (FREQ_STABLE_RANGE / 2)
    @pwm.frequency((f + noise).clamp(400, 8000))
  end

  def set_duty(d)
    @base_duty = d
    # d値に応じたランダム範囲でdutyを設定（フェード対応）
    # d=40 → 20-80%, d=20 → 10-40%, d=1 → 1-2%
    lower = (d * 0.5).to_i.clamp(1, 100)
    upper = (d * 2.0).to_i.clamp(1, 100)
    range = upper - lower
    random_duty = lower + @random.rand(range + 1)
    @pwm.duty(random_duty.clamp(1, 100))
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

  DIST_VALID_MIN = 20       # センサーが「信用できる」最小値(mm)
  DIST_VALID_MAX = 2000     # センサーが「信用できる」最大値(mm)
  FREQ_MIN = 400            # 最低周波数(Hz)。ノイズ的な低音（2オクターブアップ）
  FREQ_MAX = 8000           # 最高周波数(Hz)。攻撃的な高音（2オクターブアップ）

  BASE_DUTY = 40           # 基準duty比(%)
  DUTY_MIN = 25            # 最小duty比(%)
  DUTY_MAX = 60            # 最大duty比(%)
  DUTY_DELTA_SCALE = 20    # X軸→duty変化の感度

  VIBRATO_SCALE = 50                    # Y軸→ビブラート強さ(Hz)
  CUTOFF_SCALE = 30                     # Z軸→カットオフ風効果(duty微調整)

  DUTY_SMOOTH_FACTOR = 1                # duty変化の滑らかさ（即座反応）
  MAX_FREQ_CHANGE_PER_MS = 100          # 周波数変化速度制限(Hz/ms)。素早いグリッサンド
  FADE_RATE = 0.2                       # ノイズ時のフェードアウト減衰率(20%/frame)

  attr_reader :current_freq, :current_duty, :distance

  def initialize(speaker, tof_sensor, accel_sensor)
    @speaker = speaker
    @tof_sensor = tof_sensor
    @accel_sensor = accel_sensor

    @current_freq = FREQ_MIN
    @current_duty = 1
    @target_duty = 1
    @distance = DIST_VALID_MIN
    @prev_set_freq = nil  # 前回設定した周波数
    @prev_set_duty = nil  # 前回設定したduty
    @unstable_frames = 0  # ノイズフレームカウント

    @freq_range = FREQ_MAX - FREQ_MIN
    @dist_range = DIST_VALID_MAX - DIST_VALID_MIN
  end
  
  def update_distance
    raw_distance = @tof_sensor.read_distance

    # ノイズ判定：-1、DIST_VALID_MIN未満、DIST_VALID_MAX超
    if raw_distance < 0 || raw_distance < DIST_VALID_MIN || raw_distance > DIST_VALID_MAX
      @unstable_frames += 1
      # フェードアウト処理（段階的に音を消す）
      @target_duty = (@target_duty * (1.0 - FADE_RATE)).to_i.clamp(1, BASE_DUTY)
      puts "NOISE: #{raw_distance}, unstable=#{@unstable_frames}, duty→#{@target_duty}" if DEBUG
      return
    end

    @distance = raw_distance
    @unstable_frames = 0

    # 有効信号：周波数計算
    target_freq = FREQ_MIN + (raw_distance - DIST_VALID_MIN) * @freq_range / @dist_range
    @target_duty = BASE_DUTY

    # 速度制限（グリッサンド効果）
    freq_diff = target_freq - @current_freq
    if freq_diff > MAX_FREQ_CHANGE_PER_MS
      @current_freq += MAX_FREQ_CHANGE_PER_MS
    elsif freq_diff < -MAX_FREQ_CHANGE_PER_MS
      @current_freq -= MAX_FREQ_CHANGE_PER_MS
    else
      @current_freq = target_freq
    end

    if @prev_set_freq != @current_freq
      @speaker.frequency(@current_freq)
      @prev_set_freq = @current_freq
    end

    puts "D #{raw_distance}, TF #{target_freq}, CF #{@current_freq}" if DEBUG
  end
  
  def update_accel
    accel_data = @accel_sensor.acceleration

    vibrato = (accel_data[:y] * VIBRATO_SCALE).to_i
    new_freq = (@current_freq + vibrato).clamp(FREQ_MIN, FREQ_MAX)

    if @prev_set_freq != new_freq
      @speaker.frequency(new_freq)
      @prev_set_freq = new_freq
    end

    duty_delta = (accel_data[:x] * DUTY_DELTA_SCALE).to_i
    cutoff_effect = (accel_data[:z] * CUTOFF_SCALE).to_i
    target_with_effects = (@target_duty + duty_delta + cutoff_effect).clamp(DUTY_MIN, DUTY_MAX)

    if @target_duty == 1
      target_with_effects = 1
    end

    @current_duty += (target_with_effects - @current_duty) / DUTY_SMOOTH_FACTOR
    @current_duty = @current_duty.clamp(1, DUTY_MAX)

    if @prev_set_duty != @current_duty
      @speaker.duty(@current_duty)
      @prev_set_duty = @current_duty
    end

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
  
  def update(freq, duty, distance, accel_x, accel_y, accel_z)
    # 距離に基づいてLED波形オフセットを大きく変動
    distance_offset = (distance * 2) % 384  # distanceでオフセットが大きく変化
    @wave_offset = (distance_offset + (@wave_offset + 1)) % 384

    # 距離に基づいて色相ベースも変動
    distance_hue_shift = (distance / 10) % 384  # 距離で色相をシフト
    hue_base = ((freq - NoiseInstrument::FREQ_MIN) * 384 / NoiseInstrument::FREQ_MAX + distance_hue_shift).clamp(0, 767) % 384
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
elsif NOISE_MODE
  NoisyPWM.new(NoiseInstrument::SPEAKER_PIN, frequency: 500, duty: 30)
else
  SimplePWM.new(NoiseInstrument::SPEAKER_PIN, frequency: 100, duty: 1)
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

  led_viz.update(instrument.current_freq, instrument.current_duty, instrument.distance,
                 accel_data[:x], accel_data[:y], accel_data[:z])
  led_viz.show

  #sleep_ms(1)
end

irq.unregister
