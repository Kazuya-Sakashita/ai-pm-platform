# ADR-0013: DM由来テキストの暗号鍵rotation/KMS/backup削除方針

## Status

Accepted

## Date

2026-07-05

## Context

ISSUE-029で `conversation_imports.raw_text` と `conversation_imports.redacted_text` はActive Record Encryptionで暗号化された。productionでは以下の環境変数が未設定の場合、起動時に失敗する。

- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`
- `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`
- `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`

この実装によりDB dump単体でDM本文を読みにくくなった一方、世界レベルSaaSとしては鍵の生成、保管、rotation、漏えい時対応、backup内データ、復元後の削除再適用まで運用方針を定義する必要がある。

暗号化は、鍵管理とbackup運用が弱い場合に十分な保護にならない。特にDiscord DMは個人情報、秘密情報、未公開ロードマップ、顧客会話を含み得るため、鍵とbackupをproduct security gateとして扱う。

## Decision

DM由来テキストの本番運用では、以下を採用する。

1. productionのActive Record Encryption keyは、Git repository、CI log、Docker image、DB、application logへ保存しない。
2. 初期betaではmanaged secret storeに環境別のkey setを保存してよい。ただしpublic productionではKMS envelopeまたは同等のmanaged key protectionをrelease gateにする。
3. `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` は暗号化対象fieldの主keyとし、環境ごとに完全分離する。
4. `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` はRails設定上は必須だが、DM本文fieldではdeterministic encryptionを使わない。DM本文の検索要件が必要になっても、本文そのもののdeterministic encryptionは採用しない。
5. scheduled rotationは少なくとも180日ごとに検討し、漏えい疑い、退職/権限喪失、secret manager侵害、CI log露出の可能性がある場合は即時rotationする。
6. rotationでは旧keyを一時的なprevious keyとして保持し、新keyで新規書き込み、既存ciphertextをbatch再暗号化、検証後に旧keyを削除する。
7. backup内の暗号化済みDM本文はbackup retention期間だけ残り得る。backup restore時は必ずretention/anonymization jobと削除イベント再適用を実施してから利用可能にする。
8. DM関連backupの標準保持期限は35日以内を目標にする。法務/監査要件で延長する場合は、本文復号keyの分離、アクセス承認、復元時削除再適用を必須にする。
9. AuditLog、job log、worker log、GitHub Issue同期コメントにはraw/redacted text、AI draft JSON本文、暗号key、復号済み本文を保存しない。

## Key Set Policy

| Key | 用途 | 保管方針 | rotation |
| --- | --- | --- | --- |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | 非deterministic暗号化の主key | managed secret store、public productionではKMS envelope | 180日ごとに検討、incident時即時 |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | Rails暗号化設定互換用 | managed secret store、本文検索には使わない | primary keyと同時 |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | key derivation salt | managed secret store | primary keyと同時 |
| KMS master key | data key wrapping | cloud KMSまたは同等 | provider policyに従う。少なくとも年次レビュー |

## Rotation Runbook

1. rotation理由、対象環境、影響範囲、承認者を記録する。
2. DM import作成、summary draft生成、retention jobを一時停止または低traffic時間帯に制限する。
3. 新key setをsecret store/KMSに作成し、旧key setをprevious keyとして保持する。
4. 新keyで書き込み、旧keyで読み取り可能な設定をdeployする。Railsのprevious scheme利用可否は本番導入前にstagingで検証する。
5. `ConversationImport` の `raw_text` / `redacted_text` をbatchで再暗号化する。1 batchごとに件数、失敗件数、処理時間だけを記録し、本文は記録しない。
6. 再暗号化後、request specまたはstaging smokeで読み取り、匿名化、retention jobが動くことを確認する。
7. backup retention windowを確認する。旧backupから復元する必要がある期間は旧keyをrestricted secretとして保持する。
8. backup retention window終了後、旧keyを削除し、削除日時と承認者をAuditLogまたは運用台帳に保存する。
9. 侵害時rotationでは、旧keyを保持せず削除する選択を許可する。その場合、旧backupからDM本文を復元できないことを明記する。

## Backup and Restore Policy

### Backup

- DB backupは暗号化済みciphertextを含むが、Active Record Encryption keyとは別に保管する。
- backup storageはprovider側のat-rest encryptionを必須にする。
- raw/redacted textの復号keyとDB backupの双方へアクセスできる人を最小化する。
- 標準backup retentionは35日以内を目標にする。
- backupに残る削除済み/匿名化前データは、復元時に削除イベントとretention jobを再適用することでproductionへ戻さない。

### Restore

復元手順では、アプリを公開する前に以下を実施する。

1. 復元対象時刻と含まれるDM retention windowを記録する。
2. backupに対応するkey setをrestricted operatorのみが取得する。
3. DB migrationとschema versionを確認する。
4. `ConversationImportRetentionJob` を実行し、期限切れraw text purgeとimport匿名化を適用する。
5. 手動削除/匿名化イベントが復元時点以降にあれば再適用する。
6. Queue healthでretention jobとworker状態を確認する。
7. 復元検証ログには本文を保存しない。

## Incident Response

鍵漏えいまたは漏えい疑いがある場合:

- DM import作成とAI整理生成を停止する。
- 対象環境のkey setを即時rotationする。
- DB backup、CI log、deployment log、support artifact、operator端末の露出範囲を調査する。
- 必要に応じて旧keyを破棄し、旧backupからDM本文を復元しない方針を採用する。
- 影響を受けるproject/userへ通知するためのincident noteを作成する。

## Rationale

- DB dump単体では復号できない状態を維持できる。
- managed secret storeからKMS envelopeへ段階移行でき、初期betaとpublic productionの現実的な差を扱える。
- backup削除の物理即時削除が難しい場合でも、restore前の削除再適用によりproductionへ復活させない統制を作れる。
- 旧key保持期間をbackup retention windowと結びつけることで、可用性と削除要求の説明責任を両立できる。

## Alternatives Considered

### 環境変数secretのみで無期限運用する

不採用。

理由:

- rotation、アクセス承認、監査、漏えい時対応が弱い。
- public productionやエンタープライズ顧客への説明力が足りない。

### raw/redacted textを保存しない

将来候補。

理由:

- 最も安全だが、MVPではAI整理の再検証、誤要約修正、監査説明に短期raw保持の価値がある。
- ISSUE-032でAI draft派生データ保護と合わせて再評価する。

### backupから削除済みデータを即時物理削除する

現時点では不採用。

理由:

- 多くのmanaged backupでは個別record単位の即時物理削除が難しい。
- 代替としてbackup retentionを短くし、restore時に削除/匿名化イベントを再適用する。

## Consequences

### Positive

- ISSUE-029の暗号化実装に運用統制が加わる。
- production release前のsecurity review checklistが明確になる。
- incident時に何を止め、何をrotateし、何を通知するかを判断しやすい。
- backup復元で削除済みDMが復活するリスクを下げられる。

### Negative

- rotation実装とstaging検証が必要になる。
- KMS envelope導入まではpublic production release blockerが残る。
- 旧keyとbackup retention windowの管理が運用負荷になる。

## Follow-up

- [Done 2026-07-05] key rotation/KMS/backup削除方針をADR化する。
- [Done 2026-07-05] production security checklistを `docs/security/` に追加する。
- [Todo] Rails previous schemeを使ったstaging rotation smokeを実施する。
- [Todo] KMS providerをdeployment target決定後に選定する。
- [Todo] backup retentionをdeployment provider設定へ反映する。
- [Todo] restore時のretention/anonymization replayをrelease runbookへ追加する。
