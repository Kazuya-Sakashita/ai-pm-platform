# ADR-0002: MVPでも組織、監査、暗号化、artifact version、secret scanを採用する

## Status

Accepted

## Date

2026-06-30

## Context

AI PM Platformは会議ログ、議事録、要件、Issue、API設計、レビュー結果を扱う。これらはプロダクト戦略、顧客情報、認証情報、未公開仕様を含む可能性がある。

初期MVPでは機能を絞る必要があるが、あとから監査、暗号化、チーム権限、生成物履歴を追加すると、データ移行と信頼性の負債が大きくなる。

## Decision

MVP段階から以下を採用する。

- organizations
- memberships
- artifact_versions
- secret_scan_results
- jobs
- accepted_risks
- raw_textとAI出力の暗号化
- UI/API向けsafe_error_detail

## Rationale

- AI生成物の履歴と人間編集の差分は、プロダクト価値の中核である。
- GitHub publishやAI送信の前にsecret scanがないと、実運用で重大事故につながる。
- accepted_riskはレビューゲートを現実的に運用するために必要だが、監査なしでは危険である。
- 組織とmembershipを後付けすると、AuditLogと権限の再設計が必要になる。
- 会議ログとAI出力は機密性が高く、平文保存を標準にすべきではない。

## Consequences

良い点:

- エンタープライズ品質に近い基盤をMVPから持てる。
- ReviewOpsの信頼性が上がる。
- AI送信、GitHub公開、外部同期の安全性が上がる。
- 将来のチーム利用と監査に拡張しやすい。

悪い点:

- 実装量が増える。
- 初期DB設計が重くなる。
- 暗号化、検索、redactionの設計コストが発生する。
- accepted_riskの運用を誤るとゲートが形骸化する。

## Follow-up

- GitHub App vs OAuth AppのADRを作る。
- ActiveRecord Encryptionの具体設定を設計する。
- secret scan detectorの採用候補を比較する。
- accepted_riskの権限とUIを実装前にレビューする。

