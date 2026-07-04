# ISSUE-031: DM暗号鍵rotation/KMS/backup削除方針ADRを作成する

## Issue番号

ISSUE-031

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/31

登録日: 2026-07-05

## 背景

ISSUE-029で `conversation_imports.raw_text` と `conversation_imports.redacted_text` はActive Record Encryptionで暗号化された。しかし、暗号鍵の生成、保管、rotation、漏えい時対応、KMS移行、backup内データ削除の方針はまだ十分に定義されていない。

暗号化は鍵管理と運用手順があって初めて有効になる。鍵が環境変数に置かれるだけでは、監査、SOC2相当の統制、インシデント対応、削除要求への説明責任が弱い。

## 目的

DM由来テキストを扱うための鍵管理、rotation、KMS、backup削除、復旧時の再暗号化方針をADRとして定義し、production releaseのsecurity blockerを減らす。

## 完了条件

- `docs/decisions/` にkey rotation/KMS/backup削除ADRが保存されている
- `docs/security/` に運用チェックリストが保存されている
- STRIDE/OWASP観点のレビューが `docs/review/` に保存されている
- 本番環境変数、KMS候補、rotation間隔、緊急失効手順が明記されている
- backup内のDM本文削除/保持期限/復元時検証方針が明記されている
- ISSUE-029へADR作成結果を同期している

## スコープ

- Active Record Encryption key管理方針
- KMS採用判断
- key rotation手順
- backup retention/delete方針
- インシデント時の緊急失効手順
- ADRとセキュリティレビュー

## 非スコープ

- KMSの実クラウド設定
- 本番secret投入
- 既存データの大規模再暗号化実行
- SOC2監査証跡の正式作成

## 関連レビュー

- `docs/review/20260705_discord_dm_retention_delete_api_design_review.md`
- `docs/review/20260705_discord_dm_retention_delete_implementation_review.md`
- `docs/review/20260705_dm_key_rotation_kms_backup_policy_review.md`

## 関連ADR / Security Doc

- `docs/decisions/ADR-0013_dm_key_rotation_kms_backup_policy.md`
- `docs/security/20260705_dm_key_rotation_kms_backup_checklist.md`

## レビュー結果

ISSUE-029のレビューでは、暗号化実装は前進として評価。ただしkey rotation、KMS、backup削除方針は未実装であり、実運用では暗号化の有効性を左右するP0/P1境界のsecurity riskとして扱う。

2026-07-05にADR-0013とsecurity checklistを作成。managed secret storeからKMS envelopeへ段階移行し、public productionではKMSまたは同等のmanaged key protectionをrelease gateとする。backupは35日以内を目標にし、restore前にretention/anonymization jobと手動削除イベントを再適用する方針にした。

良かった点:

- Active Record Encryption keyの保管、rotation、incident、backup restoreを一つの運用方針に接続した。
- DM本文でdeterministic encryptionを使わない方針を明確にした。
- backupに残る削除済みデータをproductionへ復活させないrestore手順を定義した。

改善点:

- KMS providerはdeployment target未確定のため未選定。
- staging rotation smokeは未実施。
- backup retention 35日以内は方針であり、provider設定へは未反映。
- restore時retention/anonymization replayはISSUE-033でrunbook反映が必要。

検証結果:

- `git diff --check`: pass
- GitHub Actions CI: push後に確認予定

## 優先度

P0

理由:

- 鍵管理が曖昧だと暗号化の監査価値が落ちる
- backupに本文が残ると削除/匿名化要求へ説明しづらい
- 本番リリース前に運用統制として必須

## 次アクション

1. GitHub Issue #31へADR/checklist/review結果を同期する。
2. CI成功後にGitHub Issue #31をクローズする。
3. ISSUE-033でrestore時retention/anonymization replayをrelease runbookへ反映する。
4. deployment target決定後にKMS providerを選定し、ADR-0013へ追補する。
