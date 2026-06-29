# ISSUE-008: 実装前にAPI/DB設計を強化する

## GitHub Issue

登録待ち。

理由: remote未設定、GitHub CLI token invalid。

## 背景

2026-06-30のAPI設計レビューとDB設計レビューで、Jobs API、GitHub連携API、OpenAPI validation API、pagination、artifact_versions、secret_scan_results、データ暗号化方針が不足していると評価した。

## 目的

Backend/Frontend実装に進む前に、APIとDBのP0不足を解消し、レビューゲート、監査、外部連携、AI生成の再試行に耐える設計へ更新する。

## 完了条件

- Jobs APIがOpenAPIに追加されている
- GitHub connect/disconnect APIがOpenAPIに追加されている
- OpenAPI validation APIが追加されている
- pagination標準が定義されている
- artifact_versionsの採否が決定されている
- secret_scan_resultsの採否が決定されている
- organizations/membershipsのMVP採否が決定されている
- raw_textとAI出力の暗号化方針がADR化されている
- 更新後レビューが `docs/review/` に保存されている

## スコープ

- OpenAPI更新
- DB設計更新
- ADR作成
- API/DB設計レビュー更新

## 非スコープ

- 実装
- OAuth実フロー構築
- GitHub App作成

## 関連レビュー

- `docs/review/20260630_api_design_review.md`
- `docs/review/20260630_db_design_review.md`
- `docs/review/20260630_api_db_hardening_review.md`

## レビュー結果

初稿としては妥当だが、世界レベルのSaaS基準では監査性、冪等性、データ保護、外部連携の復旧性が不足している。

## 次アクション

- API設計へJobs、integration、validation、paginationを反映済み
- DB設計へartifact_versions、secret_scan_results、organizations/memberships方針を反映済み
- ADRは `docs/decisions/ADR-0002_mvp_data_security_and_hardening.md` に追加済み
- ISSUE-010としてGitHub連携方式と権限設計を進める

## 進捗

完了。GitHub Issue同期のみ登録待ち。
