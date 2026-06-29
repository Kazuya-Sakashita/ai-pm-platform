# 20260630_db_design_review

## 評価日時

2026-06-30 04:25 JST

## 評価担当

Codex as CTO, Backend Architect, Security Engineer, QA, DevOps

## 使用フレームワーク

DDD、Event Storming、STRIDE、ISO25010

## 評価対象

`docs/architecture/20260630_db_design.md`

## 良かった点

- 会議、議事録、要件、Issue Draft、OpenAPI Draft、Review、Audit Logの主要ドメインが分離されている。
- AI生成履歴を `ai_generations` として独立させており、監査性と再現性に配慮している。
- Integration tokenの暗号化保存が前提化されている。
- Review Actionを別テーブルにしており、改善サイクルを追跡しやすい。
- 状態遷移が明文化され、レビューゲート実装の土台になる。

## 改善点

- 組織、チーム、メンバーシップをMVPから含めるか未決。
- 生成物の編集履歴をどの粒度で保存するか未定義。
- jsonbを多用しており、検索、差分、型安全性の課題が残る。
- polymorphic target設計は柔軟だが、DB制約が弱くなる。
- PII、秘密情報検出結果、データ削除要求のモデルがまだ不足している。
- 大きなraw_textやAI出力をDBに直接置く場合のサイズ、暗号化、バックアップ方針が未定義。

## 優先順位

1. P0: artifact_versionsテーブルの採否を決める
2. P0: organizations/membershipsをMVPに含めるか決定
3. P0: secret_scan_resultsモデルを追加検討
4. P0: raw_textとAI出力の暗号化方針を決める
5. P1: jsonb項目の検索要件を整理
6. P1: polymorphic review targetの制約戦略を決める

## 次アクション

- DB設計の未決事項をADR化する。
- 実装前にERDを更新し、migration方針を決める。
- セキュリティレビューでデータ保持、削除、暗号化を深掘りする。

## Issue番号

ISSUE-002、ISSUE-003、ISSUE-004、ISSUE-005、ISSUE-006、ISSUE-008

GitHub Issue: 登録待ち。理由: remote未設定、GitHub CLI token invalid。
