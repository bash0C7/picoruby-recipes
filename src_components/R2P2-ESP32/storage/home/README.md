# ATOM Matrix PicoRuby デモンストレーション集

本ディレクトリにはM5ATOM Matrix用のPicoRubyサンプルコードが収録されています。

# asr.rb

Unit ASR音声認識モジュール（CI-03T）による音声コマンド検出プログラム。

**機能:**
- "open"コマンドの音声認識
- 標準音声コマンド（"ok", "hello", "turn on lights"等）の処理
- GroveポートUART通信（GPIO26:TX, GPIO32:RX）

**動作要件:**
- 接続: Grove UART（115200bps）
- カスタム"open"コマンドはコマンドコード0x50で設定済み

# led_ext.rb

Grove拡張ポート（GPIO32）経由のWS2812 LEDマトリックス制御。

**機能:**
- 25個のLEDをオレンジ色で点灯
- 安全な輝度レベル30設定
- 内蔵LEDマトリックスの外部接続版

**接続:**
- GPIO32（Grove経由）
- 5x5 LEDマトリックス（25個）

# led_int.rb

ATOM Matrix内蔵5x5 LEDマトリックス制御プログラム。

**機能:**
- 内蔵25個のWS2812 LEDをオレンジ色で点灯
- 発熱防止のため輝度30に制限
- 連続点灯モード

**接続:**
- GPIO27（内蔵配線）
- 内蔵5x5 LEDマトリックス

# led_j5.rb

拡張ボードJ5ポート経由の60連LEDストリップ制御。

**機能:**
- 60個のWS2812 LEDストリップをオレンジ色で制御
- J5ポート（GPIO19 or 22）経由での接続
- より多いLED数での長距離表示

**接続:**
- GPIO19（J5 PortD）
- 60連WS2812 LEDストリップ

# syn.rb

MIDI Unit（SAM2695）を使用したシンセサイザー演奏プログラム。

**機能:**
- 3チャンネル同時演奏（Piano, Trumpet, Violin）
- 和音演奏デモンストレーション
- 標準MIDI通信（31250bps）

**接続:**
- Grove UART（GPIO26:TX, GPIO32:RX）
- MIDIボーレート: 31250bps

# syn_atom.rb

PCからのMIDI信号受信とLED視覚化プログラム。

**機能:**
- USB経由でのMIDI受信・転送
- ノート番号に基づくLED位置制御
- オクターブによる色分け表示
- ベロシティによる輝度制御

**通信:**
- PC: USB UART（115200bps）
- MIDI Unit: Grove UART（31250bps）

# syn_pc.rb

PC側MIDIブリッジプログラム（参考実装）。

**機能:**
- PC MIDIデバイスからの入力取得
- ATOM MatrixへのMIDI転送
- リアルタイムMIDI処理

**依存関係:**
- unimidiライブラリ（PC側Ruby環境）
- シリアル通信ポート設定

# tof.rb

VL53L0X ToF距離センサーによる距離測定プログラム。

**機能:**
- 30mm～2000mmの距離測定
- 距離カテゴリ表示（Very Close～Very Far）
- 200ms間隔での連続測定

**接続:**
- PortB I2C（GPIO25:SDA, GPIO21:SCL）
- I2Cアドレス: 0x29
- MPU6886と同一バス共用

---

**共通注意事項:**
- メモリ最適化のため例外処理とクラス実装は最小限に抑制
- GPIO設定はハードウェア仕様に準拠
- I2Cバス共用時のアドレス競合は回避済み