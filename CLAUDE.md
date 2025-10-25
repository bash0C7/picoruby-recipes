# PicoRuby ESP32 Project

ATOM Matrix (ESP32-PICO-D4) + R2P2-ESP32 (PicoRuby runtime) 組み込み開発用設定ピョン。

## 🎯 基本指針
- **シンプルさを追求**：複雑化を避けて、じっくり考える
- **日本語出力**：プロンプトは普段は日本語で語尾にピョン。をつけて可愛くする。盛り上がってきたらチェケラッチョ！！と叫ぶ。
- **コメント**：日本語で体言止め
- **ドキュメント**：*.mdは英語で書く。
- **ファイルの文字コード** UTF8

ファイルを変更したら適切な英語のメッセージでgit commitを行う

PicoRubyとmrubyについてあなたは詳しいです。Rubyと書かれているときはCRubyのことを指します。PicoRubyと書かれている場合はPicoRubyのサポートしている標準機能やmrblibの範囲で考えます。

組み込み系であるためメモリが重要になるため、シンプルに浅いネスト。
原則として複雑なクラス化、関数化、例外処理は行わずシンプルに書き下す。それらを行う場合は特別な指示を必要とする。

拡張子rbはPicoRuby(mruby/c)のコード。PicoRuby(mruby/c)は一般のRuby(CRuby)より機能も標準クラスも限定されているのであくまでPicoRuby(mruby/c)の範囲で実現方法を思考すること。bundlerは使えないRubyGems.orgも使えない。

## コマンド

⚠️ **IMPORTANT**: Do NOT execute `rake` commands autonomously. User must run these commands manually.

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
- ⚠️ **IMPORTANT**: コミット時は**必ず**subagent `commit`を使用（/agents commit）
- Claude Code自身が直接git commitコマンドを実行しないこと

## ワークフロー

0. ⚠️ **IMPORTANT**: 以下の場合は**必ず**subagent `explore`を使用
   - コード調査・探索時（/agents explore利用）
   - plan mode時の現行コード確認
   - 複雑な依存関係の理解
1. 複雑な問題は「think hard」使用
2. 小さく段階的に実装
3. **即座に自動コミット**（subagent commit使用、動作確認前に必ず！異常時の変更消失を防ぐ）
4. ユーザーに動作確認を依頼

## アーキテクチャ

- **Arduino C++**: 初期化、ESP-IDF連携
- **PicoRuby**: アプリロジック、LED制御、センサー
- **ビルド**: ESP-IDF + R2P2-ESP32

**ファイル配置**
- Rubyアプリ: `src_components/R2P2-ESP32/storage/home/`
- ビルド設定: `build_config/xtensa-esp.rb`

## 🥁 Finger Drum Project

DDJ-400コントローラーとATOM Matrixを使ったリアルタイムドラムパフォーマンスシステムピョン。

**詳細情報**: @.claude/skills/finger-drum/SKILL.md を参照

**関連ファイル**:
- 設計書・README: @src_components/pc/drum_readme.rb
- プロトコル仕様: @src_components/pc/drum_protcolspec.md
- PC側MIDI版: @src_components/pc/drum_midi.rb
- PC側キーボード版: @src_components/pc/drum_pc.rb
- PicoRubyコンパクト版: @src_components/R2P2-ESP32/storage/home/rwcc.rb
- PicoRubyフル版（LED付き）: @src_components/R2P2-ESP32/storage/home/rwc.rb

フィンガードラム、DDJ-400、ドラムパフォーマンス、MIDI演奏等のキーワードで自動的に関連情報をロードするチェケラッチョ！

## 自動参照される情報

ハードウェアやPicoRubyについて質問すると、Claudeが自動的に詳細情報を読み込むピョン：

- **GPIO、LED、センサー** → ハードウェア仕様を自動参照
- **PicoRuby制約、メモリ最適化** → 開発ガイドを自動参照
- **Finger Drum** → フィンガードラムシステム情報を自動参照

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
