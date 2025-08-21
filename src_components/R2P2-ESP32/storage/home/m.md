# ATOM Matrix PicoRubyファイル一覧

本ディレクトリの全RubyファイルとMarkdownファイルの仕様・役割を記載します。

## 📂 通常レシピファイル

### 🔊 音声認識 (Unit ASR)
- **`asr.rb`** - Unit ASR音声認識デモ（シンプル版）
  - Grove UART(GPIO 26/32) + 内蔵5x5 LED(GPIO 27)
  - "hello"/"ok"コマンド認識でLED色変更
  
- **`asr_c.rb`** - Unit ASR音声認識ライブラリとクラス実装
  - Grove UART(GPIO 26/32)
  - UnitASRクラス定義とサンプル実装

### 💡 LED制御基本
- **`led_int.rb`** - 内蔵5x5 LEDマトリックス基本制御
  - 内蔵5x5 LED(GPIO 27)
  - シンプルオレンジ色点灯

- **`led_ext.rb`** - Grove外付けLED制御
  - 外付け15 LED(Grove GPIO 32)
  - オレンジ色点灯

- **`led_j3_25.rb`** - J3ポート25連LED制御
  - 外付け25 LED(J3ポートGPIO 25) + MPU6886センサー
  - 加速度応答LED制御

- **`led_j5_60.rb`** - J5ポート60連LED制御  
  - 外付け60 LED(J5ポートGPIO 22) + MPU6886センサー
  - 加速度応答LED制御

### 🎵 MIDI・シンセサイザー
- **`syn.rb`** - MIDI Unitシンセサイザー基本演奏
  - Grove UART(GPIO 26/32) + MIDI Unit
  - 3チャンネル同時演奏デモ

- **`syn_atom.rb`** - PCからのMIDI受信LED視覚化
  - USB UART + Grove UART(GPIO 26/32) + 内蔵5x5 LED(GPIO 27)
  - PC→ATOM→MIDI Unit転送＋LED視覚化

### 📏 センサー
- **`tof.rb`** - VL53L0X距離センサー測定
  - I2C(GPIO 21/25) + VL53L0Xセンサー
  - 距離測定とカテゴリ表示

- **`imu.rb`** - MPU6886 IMUセンサーデータ表示
  - 内蔵MPU6886(I2C GPIO 21/25)
  - 3軸加速度・ジャイロ・温度表示

---

## 🌸 ながらRuby会議01デモファイル

### 内蔵5x5 LEDデモ (n25*.rb)
**GPIO 27 - 内蔵25個LEDマトリックス**

- **`n25.rb`** - シンプルオレンジ点灯デモ
  - 内蔵5x5 LED(GPIO 27)
  - 基本的な連続点灯

- **`n25bash.rb`** - bashアイコン表示デモ - 3軸加速度でRGB色変化
  - 内蔵5x5 LED(GPIO 27) + MPU6886センサー + ボタン(GPIO 39)
  - bashロゴパターン表示＋加速度連動色変化

- **`n25imu.rb`** - Ruby Gemstoneデモ - 振動応答LEDパターンシミュレーション  
  - 内蔵5x5 LED(GPIO 27) + MPU6886センサー + ボタン(GPIO 39)
  - ダイヤモンドパターン＋振動応答移動

- **`n25r.rb`** - ランダムカラー表示デモ - 時刻ベース疑似乱数色変化
  - 内蔵5x5 LED(GPIO 27) + 時刻種子カラー生成
  - 時刻ベースの色変化アルゴリズム

### 外付け60 LEDデモ (n60*.rb)  
**J5ポートGPIO 22 - 外付け60個LEDストリップ**

- **`n60.rb`** - ペンライト基本デモ
  - 外付け60 LED(J5ポートGPIO 22)
  - 基本的なオレンジ点灯

- **`n60a.rb`** - ペンライトデモ - 音声認識によるオレンジ輝度制御
  - 外付け60 LED(J5ポートGPIO 22) + Unit ASR(Grove GPIO 26/32)
  - 音声コマンドで輝度変更

- **`n60d.rb`** - ペンライトデモ - VL53L0X距離センサーによる輝度制御
  - 外付け60 LED(J5ポートGPIO 22) + VL53L0X(I2C GPIO 21/25)  
  - 距離に応じた輝度制御

- **`n60notify.rb`** - Claude Code Notifyデモ
  - 外付け60 LED(J5ポートGPIO 22) + USB UART
  - PC通信による色変更通知システム

- **`n60pc.rb`** - MIDIシンセサイザーデモ - PC→LEDビジュアライザー
  - 外付け60 LED(J5ポートGPIO 22) + MIDI(USB,GPIO 23/33)
  - MIDI信号可視化＋転送

- **`n60syn.rb`** - ペンライトデモ - 音声認識MIDI効果音付き
  - 外付け60 LED(J5ポートGPIO 22) + Unit ASR(Grove GPIO 26/32) + MIDI(GPIO 23/33)
  - 音声認識＋LED＋MIDI効果音

- **`n60synimu.rb`** - IMU連動MIDIシンセサイザーデモ - 3軸加速度でマルチ楽器演奏
  - 外付け60 LED(J5ポートGPIO 22) + MPU6886センサー + MIDI(GPIO 23/33) + Unit ASR(Grove GPIO 26/32)
  - 3軸加速度による3楽器同時演奏＋LED視覚化

---

## 📄 ドキュメントファイル

- **`README.md`** - 通常レシピの詳細説明（英語プロジェクト用）
- **`n25imu.md`** - n25imu.rbのLEDパターン定義説明
- **`m.md`** - 本ファイル（全ファイル仕様一覧）

---

## 🔧 ハードウェア接続仕様

### GPIO配置
- **GPIO 27**: 内蔵5x5 LEDマトリックス（25個）
- **GPIO 22**: J5ポート外付けLEDストリップ（60個）  
- **GPIO 32**: Grove外付けLEDストリップ（15個）
- **GPIO 25**: Grove拡張ボードJ3ポート
- **GPIO 21/25**: I2C(MPU6886, VL53L0X等)
- **GPIO 26/32**: Grove UART(Unit ASR, MIDI等)
- **GPIO 23/33**: J4ポート追加UART(MIDI等)
- **GPIO 39**: プログラマブルボタン（入力専用）

### 通信プロトコル
- **I2C**: 100kHz, SDA=25, SCL=21
- **UART0**: USB通信 115200bps
- **UART1**: Grove/外部デバイス 115200bps/31250bps(MIDI)

### センサー・周辺機器
- **MPU6886**: 内蔵IMU(アドレス0x68)
- **VL53L0X**: ToF距離センサー(アドレス0x29)  
- **Unit ASR**: CI-03T音声認識モジュール
- **MIDI Unit**: SAM2695シンセサイザーチップ

---

**更新日**: 2025年8月21日  
**対象ハードウェア**: M5Stack ATOM Matrix + 各種Unitデバイス