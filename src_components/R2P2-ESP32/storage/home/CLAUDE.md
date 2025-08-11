## 🎯 基本指針
- **シンプルさを追求**：複雑化を避けて、じっくり考える
- **日本語出力**：プロンプトは日本語で語尾にニャン
- **コメント**：日本語で体言止め
- **ドキュメント**：README.mdは英語（ユーザー向け）

# 大事なこと
PicoRubyのコードを書きます

PicoRubyの公式docは https://picoruby.github.io/ にあってここから検索してください。

PC側のコードはbundlerで管理し、このディレクトリでgemを格納しグローバルは汚染しません。そしてバージョン管理にはbundlerでインストールしたライブラリのファイルそのものは管理しません。

## 環境セットアップ手順

### Bundler設定
```bash
# Gemfileを初期化
bundle init

# ローカルインストール設定
bundle config set --local path 'vendor/bundle'

# gemインストール
bundle install
```

### .gitignoreへの追加項目
```
# Bundler (recursive)
**/vendor/
**/.bundle/
**/Gemfile.lock

# Ruby artifacts (recursive)
**/*.gem
**/*.rbc
```

## UART通信テスト

### 使用gem
- `uart`: PC側でシリアル通信を行う

### テスト手順
1. PC側: `bundle exec irb`でUARTライブラリを使用
2. PicoRuby側: `app.rb`でエコープログラム実行
3. USBシリアル経由でデータ送受信テスト

### ファイル構成
- `Gemfile`: bundler設定ファイル
- `app.rb`: PicoRuby側エコープログラム（PC側手順もコメントに記載）

