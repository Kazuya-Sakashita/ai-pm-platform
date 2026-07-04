# DM暗号鍵rotation/KMS/backup削除チェックリスト

## 目的

Discord DM由来テキストをproductionで扱う前に、Active Record Encryption key、KMS、backup、restore、incident responseの確認項目を明確にする。

関連Issue: ISSUE-031

関連ADR: `docs/decisions/ADR-0013_dm_key_rotation_kms_backup_policy.md`

## Release Gate

public productionでDMインポートを有効化する前に、以下をすべて満たす。

- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` がproduction secret storeに設定されている
- `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` がproduction secret storeに設定されている
- `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` がproduction secret storeに設定されている
- key setがGit repository、CI log、Docker image、DB、application logに含まれていない
- production bootでkey未設定時に起動失敗することを確認している
- DB backupとActive Record Encryption keyの保管権限が分離されている
- backup storageのat-rest encryptionが有効である
- backup retentionが35日以内、または延長理由と承認者が記録されている
- restore前にretention/anonymizationを再適用する手順がrelease runbookにある
- KMS envelopeまたは同等のmanaged key protectionの採用判断が完了している
- rotation smokeをstagingで実施済み、または未実施理由とrelease blockerが記録されている

## Key Handling

禁止:

- keyをGitHub Issue、Pull Request、Slack、Notion、support ticketへ貼る
- keyを`.env.example`以外の設定ファイルへ実値で保存する
- keyをスクリーンショット、terminal log、CI artifactへ含める
- DM本文fieldでdeterministic encryptionを使い、本文検索に流用する

必須:

- 環境ごとにkey setを分離する
- production keyへアクセスできるoperatorを最小限にする
- key access権限の付与/剥奪を運用台帳に残す
- incident時にAI整理生成とDM import作成を停止できる手順を持つ

## Rotation Checklist

rotation実施時に記録する項目:

- rotation日時
- 対象環境
- rotation理由
- 承認者
- 実施者
- 旧key setの扱い
- backup retention window終了予定日
- 再暗号化対象件数
- 再暗号化成功件数
- 再暗号化失敗件数
- retention job実行結果
- rollback判断

実施手順:

1. 変更freezeまたは低traffic windowを確保する。
2. 新key setをsecret store/KMSで作成する。
3. 旧key setをprevious keyとして一時保持する。
4. 新key書き込み/旧key読み取り可能な設定をstagingで確認する。
5. productionへdeployする。
6. `ConversationImport` の暗号化fieldをbatch再暗号化する。
7. request specまたはmanual smokeで読み取り、匿名化、retention jobを確認する。
8. backup retention window終了まで旧keyをrestricted保管する。
9. 旧key削除後、削除日時と承認者を記録する。

## Backup Checklist

backup作成時:

- DB backupの保存先が暗号化されている
- backup保存先とkey保存先が分離されている
- backup retentionが35日以内である
- retention job失敗時のalertまたは運用確認がある
- backupにapplication logやworker logが同梱される場合、本文が含まれていないことを確認する

restore時:

- 復元対象時刻を記録する
- 復元に使うkey setを特定する
- public trafficを戻す前に `ConversationImportRetentionJob` を実行する
- 手動匿名化イベントを再適用する
- queue healthでworker/recurring taskを確認する
- 検証ログにDM本文を保存しない

## Incident Checklist

鍵漏えい疑いがある場合:

- DM import作成を停止する
- AI整理生成を停止する
- 対象key setを失効またはrotationする
- CI log、deployment log、support artifact、operator端末の露出有無を確認する
- DB backupとkeyの同時露出がないか確認する
- 影響範囲のproject/userを抽出する
- incident noteを `docs/security/` または専用incident台帳へ保存する
- 旧backupを復元しない判断が必要な場合は承認者を記録する

## STRIDE確認

| 脅威 | 確認事項 |
| --- | --- |
| Spoofing | key操作の実施者/承認者を記録する |
| Tampering | rotation/re-encryption件数を改ざんされない運用台帳へ残す |
| Repudiation | key access、rotation、restoreの証跡を残す |
| Information Disclosure | keyとbackupを分離し、logに本文/keyを出さない |
| Denial of Service | rotation失敗時のrollbackとDM import停止手順を持つ |
| Elevation of Privilege | production key accessを最小権限にする |

## 現時点の未完了

- KMS providerは未選定
- staging rotation smokeは未実施
- backup retentionはdeployment provider未定のため設定未反映
- restore時retention/anonymization replayはrelease runbook未反映
