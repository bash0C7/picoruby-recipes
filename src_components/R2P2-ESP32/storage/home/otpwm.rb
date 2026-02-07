DEBUG = true  # デバッグモード。true=デバッグ出力、false=デバッグ出力なし
NOISE_MODE = false  # ノイズ音モード。true=ノイズ音、false=通常BEEP音

module Speaker
  def initialize_speaker(muted: true)
    @muted = muted
    @target_duty = 0
  end

  def frequency(f)
    set_frequency(f)
  end

  def duty(d)
    @target_duty = d
    set_duty(@muted ? 0 : d)
  end

  def toggle_mute
    @muted = !@muted
    set_duty(@muted ? 0 : @target_duty)
    puts "Mute: #{@muted}" if DEBUG
  end

  def muted?
    @muted
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
    initialize_speaker(muted: param[:muted] == false ? false : true)
    puts "new #{pin}, #{param.to_s}"
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
    initialize_speaker(muted: param[:muted] == false ? false : true)
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
    initialize_speaker(muted: param[:muted] == false ? false : true)
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

    @freq_ratio = FREQ_MAX.to_f / FREQ_MIN  # 周波数比率（対数スケール用）
    @dist_range = DIST_VALID_MAX - DIST_VALID_MIN
  end
  
  def update
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

    @current_duty += (@target_duty - @current_duty) / DUTY_SMOOTH_FACTOR
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
  
  def update(freq, duty, distance)
    # 距離に基づいてLED波形オフセットを制御（距離が変わってなければオフセットも固定）
    @wave_offset = (distance * 2) % 384  # distanceだけで決定。距離が変わってなければ固定

    # 色相：距離を4帯域に分割し、帯域ごとに色を割り当て
    # 帯域1(20-80mm)=赤系(0-96), 帯域2(80-160mm)=シアン系(96-192), 帯域3(160-240mm)=マゼンタ系(192-288), 帯域4(240-300mm)=黄系(288-384)
    dist_range = NoiseInstrument::DIST_VALID_MAX - NoiseInstrument::DIST_VALID_MIN
    band_width = dist_range / 4
    relative_dist = (distance - NoiseInstrument::DIST_VALID_MIN).to_i

    band = (relative_dist / band_width).clamp(0, 3)
    within_band = relative_dist % band_width

    hue_bands = [0, 96, 192, 288]  # 各帯域の色相開始値
    hue_base = hue_bands[band] + (within_band * 96 / band_width)

    # 彩度：固定
    saturation = 200

    # 輝度：dutyの値で決定（1-60 → 10-100の線形マッピング）
    brightness = ((duty - 1) * 90 / (NoiseInstrument::DUTY_MAX - 1) + 10).clamp(10, 100)

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

speaker = if NOISE_MODE
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

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {viz: led_viz, spk: speaker}) do |btn, ev, cap|
  cap[:spk].toggle_mute
  cap[:viz].flash
end

loop_counter = 0

loop do
  IRQ.process

  # 毎フレーム distance を処理
  instrument.update

  if loop_counter % 4 == 0
    led_viz.update(instrument.current_freq, instrument.current_duty, instrument.distance)
    led_viz.show
  end

  loop_counter += 1

  #sleep_ms(1)
end

irq.unregister
