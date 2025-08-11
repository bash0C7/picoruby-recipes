## 🎯 基本指針
- **シンプルさを追求**：複雑化を避けて、じっくり考える
- **日本語出力**：プロンプトは普段は日本語で語尾にピョン。をつけて可愛くする。盛り上がってきたらチェケラッチョ！！と叫ぶ。
- **コメント**：日本語で体言止め
- **ドキュメント**：プロジェクトルートのREADME.mdは英語（ユーザー向け）。サブディレクトリのREADME.mdは日本語
- **ファイルの文字コード** UTF8

ファイルを変更したら適切な英語のメッセージでgit commitを行う

PicoRubyとmrubyについてあなたは詳しいです。Rubyと書かれているときはCRubyのことを指します。PicoRubyと書かれている場合はPicoRubyのサポートしている標準機能やmrblibの範囲で考えます。

組み込み系であるためメモリが重要になるため、シンプルに浅いネスト。
原則として複雑なクラス化、関数化、例外処理は行わずシンプルに書き下す。それらを行う場合は特別な指示を必要とする。

拡張子rbはPicoRuby(mruby/c)のコード。PicoRuby(mruby/c)は一般のRuby(CRuby)より機能も標準クラスも限定されているのであくまでPicoRuby(mruby/c)の範囲で実現方法を思考すること。bundlerは使えないRubyGems.orgも使えない。

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

The project uses a hybrid architecture combining Arduino C++ and Ruby:


**Ruby Layer (PicoRuby on ESP32)**:
- Ruby scripts for LED control, sensor demos
- Located in `src_components/R2P2-ESP32/storage/home/`
- Uses RMT peripheral for WS2812 LED control
- MPU6886 sensor integration for motion detection

**Build System**:
- Dual-layer build using ESP-IDF + R2P2-ESP32 (PicoRuby runtime)
- Ruby gems configured in `build_config/xtensa-esp.rb`
- Source components (`src_components/`) copied to build location (`components/`)

## Key Build Commands

**Initial setup**:
```bash
rake init
```

**Regular development build**:
```bash
rake build
```

**Update dependencies**:
```bash
rake update
```

**Clean rebuild**:
```bash
rake cleanbuild
```

**Check environment**:
```bash
rake check_env
```

**View all tasks**:
```bash
rake -T
```

## Development Environment

**Requirements**:
- ESP-IDF installed at `$HOME/esp/esp-idf/`
- Homebrew with OpenSSL
- Git with submodule support

**Important Environment Variables**:
- All ESP-IDF environment setup is handled automatically by Rake tasks
- ESPBAUD=115200 for flashing
- OpenSSL paths configured for Homebrew installation

## File Structure Logic

- **Project Root**: Arduino sketch and build configuration
- **`src_components/`**: Source directory for ESP-IDF components (tracked in git)
- **`components/`**: Build-time directory (auto-generated, git-ignored)
- **`components/R2P2-ESP32/`**: Cloned PicoRuby runtime environment
- **Ruby Files**: Located in `src_components/R2P2-ESP32/storage/home/`

## Development Notes

- The Ruby runtime executes on ESP32 via PicoRuby, accessed through R2P2-ESP32 components
- All Ruby gems are configured in `build_config/xtensa-esp.rb`
- LED patterns use RMT peripheral for precise timing control
- Memory optimization is critical - use pre-allocated arrays and avoid dynamic allocation
- Sensor calibration uses squared values to eliminate expensive sqrt operations

# Hardware Spec

正確なハードウェア仕様

## 基本仕様
- **SoC**: ESP32-PICO-D4（240MHz デュアルコア）
- **Flash**: 4MB SPI Flash
- **サイズ**: 24.0 x 24.0 x 13.8mm
- **電源**: 5V @ 500mA（USB Type-C）

## LED・表示デバイス
- **内蔵5x5 LED**: WS2812C 2020 x 25個（GPIO 27）
- **推奨輝度**: 20（FastLED使用時）、0-100（M5Atom library使用時）
- **赤外線LED**: GPIO 39（送信専用）

## センサー
- **内蔵IMU**: MPU6886（I2Cアドレス: 0x68）
  - SCL: GPIO 21
  - SDA: GPIO 25
  - **I2Cアドレス**: 0x68 (7bit)
  - **機能**: 3軸加速度センサー + 3軸ジャイロスコープ

## GPIO配置

### Groveポート（HY2.0-4P） G26, G32
**4ピン構成（2.0mm間隔）:**
```
ピン配置: [Black] [Red] [Yellow] [White]
         [GND]  [5V] [GPIO26] [GPIO32]
```

**利用例:**
- **I2C接続**: GPIO26→SDA, GPIO32→SCL
- **UART接続**: GPIO26→TX, GPIO32→RX  
- **デジタルI/O**: 汎用入出力として利用可能
- **アナログ入力**: GPIO32のみ対応（ADC1_CH4）

### 背面GPIOピン（2.54mm間隔）
**ピン配置:**
```
表から見て左側: G21(SCL), G25(SDA)  ← MPU6886が接続済み（他I2Cデバイス併用可能）
表から見て右側: G22(RX), G19(TX), G23, G33
```

**機能詳細:**
- **G19, G22**: UART2用途に適している
- **G23, G33**: アナログ入力対応（ADC1_CH6, ADC1_CH5）
- **G21, G25**: I2Cバス（MPU6886: 0x68 + 他I2Cデバイス併用可能）

### Grove拡張ボード使用時
**拡張ボード接続時のポート割り当て:**
- **J3(PortB)**: G25, G21 - I2C用途（MPU6886: 0x68と共用、異なるアドレスなら併用可能）
- **J4(PortC)**: G23, G33 - アナログ入力専用
- **J5(PortD)**: G19, G22 - シリアル通信用途

## ボタン・入力
- **プログラマブルボタン**: GPIO 39（LEDマトリックス下に配置）
- **リセットボタン**: 本体側面

## 通信インターフェース
- **USB**: Type-C（プログラム書き込み・シリアル通信）
- **Grove**: HY2.0-4P x 1（I2C+汎用I/O+UART対応）
- **Wi-Fi**: 2.4GHz 802.11 b/g/n
- **Bluetooth**: Classic + BLE

## 重要な制約・注意事項

### GPIO使用上の注意
1. **G21, G25**: MPU6886(0x68)が接続済み、他I2Cデバイス(異なるアドレス)と併用可能
2. **G27**: 内蔵LEDマトリックス専用
3. **G39**: 入力専用（プルアップ・プルダウン不可）
4. **G32, G33**: アナログ入力対応
5. **アナログ入力**: Wi-Fi使用時はG32, G33のみ推奨
6. **I2C併用時**: プルアップ抵抗、電気的負荷、アドレス競合に注意

### 電源・消費電力
- **LED輝度注意**: 高輝度設定時はアクリルパネル損傷の可能性
- **推奨動作環境**: 0°C ～ 60°C
- **最大消費電流**: 500mA（USB Type-C供給時）

### PicoRuby/mruby実装での考慮点
- **メモリ制約**: RAM 520KB（システム使用分を除く）
- **I2C初期化**: MPU6886用（SDA:25, SCL:21, 100kHz推奨）
- **I2C併用**: 同一バス上で複数デバイス利用可能（アドレス0x68以外）
- **LED制御**: RMTドライバー使用（GPIO 27）
- **Grove利用**: 用途に応じてGPIO26, 32を設定

## 検証済み実装例
```ruby
# I2C初期化（MPU6886）
i2c = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: 25, scl_pin: 21)
mpu = MPU6886.new(i2c)  # I2Cアドレス 0x68 自動設定

# LED初期化
led = WS2812.new(RMTDriver.new(27))

# Grove UART利用例
uart = UART.new(unit: :ESP32_UART1, baudrate: 115200, txd_pin: 26, rxd_pin: 32)

# MPU6886センサー読み取り例
acceleration = mpu.acceleration  # {x: 0.1, y: 0.0, z: 1.0}
gyroscope = mpu.gyroscope       # {x: 0.0, y: 0.0, z: 0.0}

# 他のI2Cデバイス併用例（LCD等）
# 同じI2Cバス上で異なるアドレス（例：0x3e）のデバイスも利用可能
i2c.write(0x3e, 0x00, 0x38)  # LCD初期化例
```

この仕様は公式ドキュメント（docs.m5stack.com）および実装検証に基づく正確な情報です。I2Cバスの併用可能性についても実装例で検証済みです。


# ATOM Matrix UART通信仕様
UART初期化パターン
1. USBシリアル通信（PC接続）
# USB Type-C経由でPCとシリアル通信
uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)

特徴:
UART Unit: ESP32_UART0（システム固定）
GPIO pin: 自動設定（pin指定不要）
接続方法: USB Type-C ケーブル経由
用途: PCとのデバッグ通信、データ送受信
ボーレート: 115200bps（標準）
実装例:
require 'uart'

uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)
uart.puts "Hello PC"

loop do
  input = uart.read
  if input == "red"
    uart.puts "RED received"
  end
  sleep_ms 50
end

2. Groveポートシリアル通信（外部デバイス接続）
# Groveポート経由で外部デバイスとシリアル通信
uart = UART.new(
  unit: :ESP32_UART1, 
  baudrate: 115200,     # または38400（デバイス依存）
  txd_pin: 26,          # Grove SDA → UART TX
  rxd_pin: 32           # Grove SCL → UART RX
)

特徴:
UART Unit: ESP32_UART1
GPIO pin: 明示的指定が必要
txd_pin: 26 (Grove SDA端子を送信用に転用)
rxd_pin: 32 (Grove SCL端子を受信用に転用)
接続方法: Groveケーブル経由
用途: Unit ASR、LCD表示デバイス、外部センサー等
ボーレート: デバイス仕様に依存（38400, 115200等）
実装例:
require 'uart'

# Unit ASR接続例
uart = UART.new(
  unit: :ESP32_UART1, 
  baudrate: 115200, 
  txd_pin: 26, 
  rxd_pin: 32
)

# Unit ASR初期化
uart.write("\xAA\x55\xB1\x05")
sleep_ms(500)

# LCD表示デバイス接続例（38400bps）
uart_lcd = UART.new(
  unit: :ESP32_UART1, 
  baudrate: 38400, 
  txd_pin: 26, 
  rxd_pin: 32
)

uart_lcd.puts "@MD2"  # モード設定
uart_lcd.puts "@ACHello World"  # テキスト表示

使い分けガイドライン
USBシリアル通信を選ぶ場合
PCとのデバッグ・開発時通信
データログ収集
リアルタイムモニタリング
設定値の送受信
Groveポートシリアル通信を選ぶ場合
外部デバイスとの制御通信
Unit ASR（音声認識）
LCD表示デバイス
他のマイコンとの連携
注意事項
GPIO使用上の制約
Groveポート使用時: GPIO26, 32がUART専用となり、I2C利用不可
同時利用: USBシリアル（UART0）とGroveシリアル（UART1）は同時利用可能
I2C併用: Groveポートシリアル使用時は、内蔵I2C（MPU6886: SDA=25, SCL=21）のみ利用可能
ボーレート設定
115200bps: 汎用的な高速通信（推奨）
38400bps: 特定デバイス（LCD表示デバイス等）で要求される場合
9600bps: 低速安定通信が必要な場合
エラーハンドリング
# 受信データ確認
if uart.bytes_available > 0
  data = uart.read
  # データ処理
end

# 送信確認
begin
  uart.write("command")
rescue => e
  puts "UART送信エラー: #{e.message}"
end


