# DM暗号鍵rotation/KMS/backup削除方針レビュー

## 評価日時

2026-07-05 06:52:58 JST

## 評価担当

Codex as CTO / Tech Lead / Backend Architect / DevOps / Security Engineer / QA / Product Manager

## 使用フレームワーク

- ADR
- STRIDE
- OWASP Top 10
- ISO25010

## Issue番号

ISSUE-031

## 評価対象

- `docs/decisions/ADR-0013_dm_key_rotation_kms_backup_policy.md`
- `docs/security/20260705_dm_key_rotation_kms_backup_checklist.md`

## 良かった点

- ISSUE-029で実装した暗号化を、鍵管理、rotation、KMS、backup、restoreまで運用方針に接続した。
- managed secret storeからKMS envelopeへ段階移行する現実的な道筋を定義した。
- backupに削除済み/匿名化前データが残る問題を、短期retentionとrestore前のretention/anonymization再適用で扱った。
- DM本文でdeterministic encryptionを使わない方針を明記し、本文検索のために暗号化強度を落とすリスクを避けた。
- incident時にDM import/AI整理生成を止める判断を運用手順に含めた。

## 改善点

- KMS providerが未選定のため、public production release gateはまだ解除できない。
- Rails previous schemeを使った実rotation smokeは未実施であり、手順の実効性はstaging検証が必要。
- backup retention 35日以内は方針であり、deployment provider設定へは未反映。
- restore時のretention/anonymization replayはrelease runbookへ未反映。
- Conversation Summary Draft JSON本文の暗号化/短期保持はISSUE-032へ残っている。

## 優先順位

| Priority | 項目 | 理由 |
| --- | --- | --- |
| P0 | KMS provider選定 | public production release gate |
| P0 | staging rotation smoke | rotation手順が机上で終わらないようにする |
| P0 | backup retention設定 | 削除/匿名化要求の説明責任に必要 |
| P0 | restore時retention replay runbook | backup restoreで削除済みDMを復活させないため |
| P1 | key access運用台帳 | beta運用中に監査粒度を上げる |

## 次アクション

1. ISSUE-033でworker smoke runbookへretention jobとrestore後実行手順を追加する。
2. deployment target決定後、KMS providerとbackup retention設定をADR追補する。
3. staging環境でActive Record Encryption rotation smokeを実施する。
4. ISSUE-032でAI整理draft JSON本文の暗号化/短期retentionを決める。
5. ISSUE-031へGitHub同期コメントを残し、CI成功後にクローズする（完了）。

## STRIDE / OWASP評価

| 観点 | 評価 | 残課題 |
| --- | --- | --- |
| Spoofing | key操作の承認者/実施者記録を要求した | 実運用台帳は未実装 |
| Tampering | 再暗号化件数と失敗件数を記録する方針にした | 改ざん耐性のある保存先は未定 |
| Repudiation | rotation/restore/incident証跡を必須化した | 認証ユーザーとの紐付けはISSUE-030 |
| Information Disclosure | keyとbackupの分離、log禁止、KMS gateを定義した | KMS provider未選定 |
| Denial of Service | rotation中のfreeze/rollbackを定義した | 実staging smoke未実施 |
| Elevation of Privilege | production key access最小化を明記した | 実IAM設計はdeployment決定後 |

## ISO25010評価

| 品質特性 | 評価 |
| --- | --- |
| Security | 方針として改善。ただしKMS未選定で条件付き合格 |
| Reliability | restore前retention replayで復元リスクに対処 |
| Maintainability | ADR/checklist化で運用判断が追跡可能 |
| Portability | cloud provider未確定でもmanaged secret store/KMS方針として転用可能 |

## 判定

条件付き合格。ISSUE-031のドキュメント成果物としては完了扱いにできるが、production-ready判定はKMS provider選定、staging rotation smoke、backup retention設定、restore runbook反映が完了するまで不可。

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPTなど外部AIレビューは未実施。外部レビュー結果が追加された場合は、KMS必須時期、backup retention期間、旧key保持期間の妥当性を比較する。
