# PicoRuby ESP32 Project

ATOM Matrix (ESP32-PICO-D4) + R2P2-ESP32 (PicoRuby runtime) 組み込み開発用設定ピョン。

## コマンド

```bash
rake init        # 初回セットアップ
rake build       # ビルド
rake cleanbuild  # クリーンビルド
rake check_env   # 環境確認
```

## コードスタイル

**Ruby (.rb)**
- 組み込み制約: 浅いネスト、シンプルに
- メモリ重視: 配列事前確保、動的確保避ける
- コメント: 日本語、体言止め
- PicoRuby/mruby標準機能のみ（CRuby不可）

**ドキュメント (.md)**
- 英語

**Gitコミット**
- 英語、命令形
- 編集後にサブエージェントでメッセージつくって自動コミット(/agents commit利用)

## ワークフロー

0. 調査はサブエージェントで高速かつ的確に行う(/agents explore利用)
1. 複雑な問題は「think hard」使用
2. 小さく段階的に実装
3. ハードウェアで動作確認
4. 自動コミット

## アーキテクチャ

- **Arduino C++**: 初期化、ESP-IDF連携
- **PicoRuby**: アプリロジック、LED制御、センサー
- **ビルド**: ESP-IDF + R2P2-ESP32

**ファイル配置**
- Rubyアプリ: `src_components/R2P2-ESP32/storage/home/`
- ビルド設定: `build_config/xtensa-esp.rb`

## 自動参照される情報

ハードウェアやPicoRubyについて質問すると、Claudeが自動的に詳細情報を読み込むピョン：

- **GPIO、LED、センサー** → ハードウェア仕様を自動参照
- **PicoRuby制約、メモリ最適化** → 開発ガイドを自動参照

覚える必要なし！必要な時だけ自動ロードされるチェケラッチョ！

## 制約

- **メモリ**: 520KB RAM（システム分除く）
- **Rubyライブラリ**: 標準のみ（gem不可）
- **コード**: 浅いネスト、複雑なクラス避ける
- **文字コード**: UTF-8

## 環境

- **ESP-IDF**: `$HOME/esp/esp-idf/` (rake自動設定)
- **フラッシュ速度**: 115200

---

**Note**: この設定ファイルは簡潔に保つピョン。詳細情報は必要な時だけ自動ロードされるチェケラッチョ！
