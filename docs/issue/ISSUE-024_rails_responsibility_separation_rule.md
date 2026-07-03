# ISSUE-024: Rails責務分離ルールをAGENTSへ追加する

## Issue番号

ISSUE-024

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/24

登録理由: Rails実装前にController / Modelへ処理を詰め込みすぎないよう、今後の開発判断ルールをAGENTS.mdへ明文化するため。

登録日: 2026-07-03

## 背景

AI PM Platformは、GitHub連携、AI生成、レビュー、監査、外部連携復旧など業務処理が増えている。Rails実装を急ぐと、ControllerやModelに業務ロジック、外部API処理、レスポンス整形、状態遷移が集まりやすくなる。

世界レベルのSaaSとして保守性、拡張性、テスト容易性を維持するには、実装前に責務分離方針を確認し、Service Object、Result Object、Query/Finder、Validator、Serializer、Policy、Adapter/Gatewayなどの切り出し先を適切に選ぶ必要がある。

## 目的

Rails実装時の責務分離チェックをAGENTS.mdへ追加し、今後の実装レビューで必ず「責務分離方針」「配置」「過剰設計を避けた理由」「テスト方針」「変更ファイル一覧」を示すようにする。

## 完了条件

- `AGENTS.md` にRails責務分離ルールが追加されている
- Controller、Model、Service Object、Result Object、Query/Finder、Form、Validator、Serializer、Policy、Adapter/Gateway、DI、Strategy、State、Value Object、Null Objectの判断基準が記載されている
- 過剰設計禁止が明記されている
- Rails実装時の報告項目が明記されている
- レビュー結果が `docs/review/` に保存されている
- GitHub Issueへ同期されている

## スコープ

- `AGENTS.md` の開発ルール追加
- Issue台帳
- レビュー文書
- GitHub Issue同期

## 非スコープ

- 既存Railsコードの大規模リファクタリング
- RuboCop/静的解析ルールの導入
- 自動アーキテクチャチェック
- Controller/Modelの即時分割

## 関連レビュー

- `docs/review/20260703_rails_responsibility_separation_rule_review.md`

## レビュー結果

2026-07-03にCodex一次レビューを実施。Rails責務分離ルールは、今後のGitHub連携、Discord DM整理、AIレビュー、認証/監査実装の品質維持に有効。ただし、ルールだけでは技術負債を防げないため、実装時レビューとテストで継続確認する必要がある。

良かった点:

- Controller / Modelへ処理を詰め込まない判断基準をAGENTS.mdへ追加した。
- Service Object、Result Object、Adapter/Gatewayなど既存設計と相性のよい切り出し先を明記した。
- 過剰設計禁止を明記し、短く単純な処理を無理にクラス化しない方針にした。
- 実装時に責務分離方針、配置、テスト方針、変更ファイル一覧を必ず示す運用にした。

改善点:

- 既存Controllerの長さや責務過多を自動検知する仕組みは未実装。
- RuboCop、Packwerk、依存方向チェックなどの静的ガードは未導入。
- Serializer/Policy/Formなどの導入基準は文章化したが、具体的なサンプル実装は未作成。

## 優先度

P0

理由:

- 今後のBackend実装速度が上がるほど、責務混在による技術負債リスクが高まる
- AI PM Platformは外部APIとAI処理が多く、Controller/Model肥大化を早期に防ぐ必要がある
- AGENTS.mdは以後の開発判断に使われる最優先ルールである

## 次アクション

- GitHub Issueへ同期する
- `AGENTS.md` 変更をcommit/pushする
- 次回以降のRails実装で責務分離方針を最終報告に含める
- 必要に応じて代表的なService/Result/Serializerのサンプルを `docs/architecture/` に追加する
