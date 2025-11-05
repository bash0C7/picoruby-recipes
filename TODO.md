# TODO: Project Maintenance Tasks

## Cleanup Tasks (後で実行)

### 既存ファイル・ディレクトリの整理

- [ ] `src_components/` ディレクトリを削除
  - `src_components/R2P2-ESP32/storage/home/` は既に `storage/home/` に移行済み
  - `src_components/pc/` は確認してから削除判断

- [ ] `components/` ディレクトリを削除
  - `.gitignore` に `/components/` があるため、Gitには入っていない
  - ビルド時に自動生成されるため、削除しても問題なし

- [ ] 既存 `Rakefile` を削除
  - `Rakefile.rb` で置き換わった
  - 動作確認後に削除

## Enhancement Tasks

- [ ] `rake env:latest` の完全実装
  - GitHub API または `git ls-remote` で最新コミット取得
  - 自動的に .picoruby-env.yml に追記
  - キャッシュ取得と環境構築を一度に実行

- [ ] キャッシュ圧縮機能（オプション）
  - `tar.gz` で`.cache/`を圧縮
  - S3/Cloud ストレージへのバックアップ

- [ ] CI/CD 統合
  - GitHub Actions でキャッシュの自動更新

## Documentation Tasks

- [ ] RAKEFILE_SPEC.md に変更履歴セクション拡張
- [ ] クイックスタートガイド作成（別ファイル）
