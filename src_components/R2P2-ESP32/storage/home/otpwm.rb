DEBUG = true  # デバッグモード。true=デバッグ出力、false=デバッグ出力なし
MUTE = false   # PWM消音モード。true=音を出さず数字を表示 false=実際に音を出す
NOISE_MODE = false  # ノイズ音モード。true=ノイズ音、false=通常BEEP音

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

class NoiseInstrument
  SPEAKER_PIN = 33
  I2C_SDA_PIN = 25
  I2C_SCL_PIN = 21

  DIST_VALID_MIN = 20       # センサーが「信用できる」最小値(mm)
  DIST_VALID_MAX = 300     # センサーが「信用できる」最大値(mm)
  FREQ_MIN = 200            # 最低周波数(Hz)。
  FREQ_MAX = 1000           # 最高周波数(Hz)。

  BASE_DUTY = 40           # 基準duty比(%)
  DUTY_MIN = 25            # 最小duty比(%)
  DUTY_MAX = 60            # 最大duty比(%)

  WAH_DEPTH_SCALE = 10      # 加速度→ワウ深さ変換係数（duty変調±%）
  WAH_SPEED = 50            # ワウLFOの周期（フレーム数、大きいほど遅い）

  DUTY_SMOOTH_FACTOR = 1                # duty変化の滑らかさ（即座反応）
  FADE_RATE = 0.2                       # ノイズ時のフェードアウト減衰率(20%/frame)
  DISTANCE_SMOOTH_ALPHA = 50             # EMA係数（整数演算用: 0-100）50=差分の50%追随

  attr_reader :current_freq, :current_duty, :distance

  def initialize(speaker, tof_sensor)
    @speaker = speaker
    @tof_sensor = tof_sensor

    @current_freq = FREQ_MIN
    @current_duty = 1
    @target_duty = 1
    @distance = DIST_VALID_MIN
    @prev_distance = DIST_VALID_MIN  # EMA用の前回値
    @prev_set_freq = nil  # 前回設定した周波数
    @prev_set_duty = nil  # 前回設定したduty
    @unstable_frames = 0  # ノイズフレームカウント

    @wah_phase = 0           # ワウLFOの位相（0～WAH_SPEED-1）

    @freq_ratio = FREQ_MAX.to_f / FREQ_MIN  # 周波数比率（対数スケール用）
    @dist_range = DIST_VALID_MAX - DIST_VALID_MIN
  end
  
  def update(accel_data)
    # 距離計測とフィルタリング
    raw_distance = @tof_sensor.read_distance

    # ノイズ判定：-1、DIST_VALID_MIN未満、DIST_VALID_MAX超
    if raw_distance < 0 || raw_distance < DIST_VALID_MIN || raw_distance > DIST_VALID_MAX
      @unstable_frames += 1
      # フェードアウト処理（段階的に音を消す）
      @target_duty = (@target_duty * (1.0 - FADE_RATE)).to_i.clamp(1, BASE_DUTY)
      puts "NOISE: #{raw_distance}, unstable=#{@unstable_frames}, duty→#{@target_duty}" if DEBUG
      return
    end

    # EMAで距離を平滑化（整数演算）
    delta = raw_distance - @prev_distance
    @distance = @prev_distance + (delta * DISTANCE_SMOOTH_ALPHA / 100)
    @prev_distance = @distance
    @unstable_frames = 0

    # 周波数計算：対数スケール（オクターブ感覚）
    # freq = FREQ_MIN * (FREQ_MAX / FREQ_MIN) ^ (distance_ratio)
    distance_ratio = (@distance - DIST_VALID_MIN).to_f / @dist_range
    @current_freq = (FREQ_MIN * (@freq_ratio ** distance_ratio)).to_i
    @target_duty = BASE_DUTY

    if @prev_set_freq != @current_freq
      @speaker.frequency(@current_freq)
      @prev_set_freq = @current_freq
    end

    puts "D #{raw_distance}, SD #{@distance}, CF #{@current_freq}" if DEBUG

    # ワウ効果：加速度の合計値でワウ深さを決定
    magnitude = accel_data[:x].abs + accel_data[:y].abs + accel_data[:z].abs

    # 三角波LFO生成: -100 ～ +100 の範囲
    half_period = WAH_SPEED / 2
    if @wah_phase < half_period
      lfo = -100 + (@wah_phase * 200 / half_period)
    else
      lfo = 100 - ((@wah_phase - half_period) * 200 / half_period)
    end
    @wah_phase = (@wah_phase + 1) % WAH_SPEED

    # ワウ効果適用：magnitude × LFO × スケール係数
    wah_depth = (magnitude * WAH_DEPTH_SCALE).to_i
    wah_modulation = (lfo * wah_depth / 100).to_i

    # target_dutyにワウ変調を加算
    target_with_effects = (@target_duty + wah_modulation).clamp(DUTY_MIN, DUTY_MAX)

    if @target_duty == 1
      target_with_effects = 1
    end

    @current_duty += (target_with_effects - @current_duty) / DUTY_SMOOTH_FACTOR
    @current_duty = @current_duty.clamp(1, DUTY_MAX)

    if @prev_set_duty != @current_duty
      @speaker.duty(@current_duty)
      @prev_set_duty = @current_duty
    end
  end
end

class AmbientLEDVisualizer
  LED_PIN = 26
  LED_COUNT = 29
  
  def initialize(led_strip)
    @led_strip = led_strip
    @led_colors = Array.new(LED_COUNT, 0)
    @wave_offset = 0
  end
  
  def update(freq, duty, distance, accel_x, accel_y, accel_z)
    # 距離に基づいてLED波形オフセットを大きく変動
    distance_offset = (distance * 2) % 384  # distanceでオフセットが大きく変化
    @wave_offset = (distance_offset + (@wave_offset + 1)) % 384

    # 色相：距離のみで決定（DIST_VALID_MIN～DIST_VALID_MAX → 0～384）
    hue_base = ((distance - NoiseInstrument::DIST_VALID_MIN) * 384 / (NoiseInstrument::DIST_VALID_MAX - NoiseInstrument::DIST_VALID_MIN)).to_i

    # 彩度：基本200（鮮やか）、加速度で最大255まで上昇
    accel_xy = ((accel_x.abs + accel_y.abs) * 55).to_i  # 最大55を加算
    saturation = (200 + accel_xy).clamp(200, 255)

    # 輝度：加速度（Z軸）で決定、静止時でも30%を保持
    accel_z_effect = (accel_z.abs * 30).to_i  # 最大30を加算
    brightness = (30 + accel_z_effect).clamp(30, 60)

    LED_COUNT.times do |i|
      hue = (hue_base + @wave_offset + i * 10) % 384
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
  DPWM.new(NoiseInstrument::SPEAKER_PIN, frequency: 100, duty: 0, mute: MUTE)
elsif NOISE_MODE
  NoisyPWM.new(NoiseInstrument::SPEAKER_PIN, frequency: 500, duty: 0)
else
  SimplePWM.new(NoiseInstrument::SPEAKER_PIN, frequency: 100, duty: 0)
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

instrument = NoiseInstrument.new(speaker, tof_sensor)
led_viz = AmbientLEDVisualizer.new(led_strip)

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {viz: led_viz}) do |btn, ev, cap|
  cap[:viz].flash
end

accel_data = {x: 0, y: 0, z: 0}
loop_counter = 0

loop do
  IRQ.process

  # 5フレームごとに加速度を取得（重い処理）
  if loop_counter % 5 == 0
    accel_data = accel_sensor.acceleration
  end

  # 毎フレーム distance + accel を処理
  instrument.update(accel_data)

  if loop_counter % 2 == 0
    led_viz.update(instrument.current_freq, instrument.current_duty, instrument.distance,
                 accel_data[:x], accel_data[:y], accel_data[:z])
    led_viz.show
  end

  loop_counter += 1

  #sleep_ms(1)
end

irq.unregister
