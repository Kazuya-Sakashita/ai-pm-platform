# GitHub Webhook secret rotation runbook

## 目的

GitHub App webhook secretを、deliveryの取りこぼしとsecret漏えいリスクを抑えながら交換する。

関連:

- ISSUE-068 / GitHub Issue #108
- ADR: `docs/decisions/ADR-0021_github_webhook_secret_rotation.md`

## Secret Handling

以下はGit、GitHub Issue、PR、レビュー文書、ログ、AIチャットへ保存しない。

- GitHub Webhook secret
- `X-Hub-Signature-256`
- raw delivery id
- raw payload全文
- secret storeのexport

保存してよいのは、環境変数名、commit SHA、実行時刻、成功/失敗、safe error code、delivery digestのみ。

## 通常rotation

1. 新secretをsecret storeへ作成する。
2. stagingへ以下を設定する。
   - `GITHUB_WEBHOOK_SECRET`: 新secret
   - `GITHUB_WEBHOOK_PREVIOUS_SECRET`: 旧secret
3. stagingをdeployする。
4. 旧secret署名と新secret署名がどちらも受理されることを確認する。
5. productionへ同じ設定をdeployする。
6. GitHub App側のwebhook secretを新secretへ切り替える。
7. GitHub deliveryが202で受理され、`GithubWebhookDelivery` にdigest保存されることを確認する。
8. 最大24時間以内に `GITHUB_WEBHOOK_PREVIOUS_SECRET` を削除する。
9. 旧secret署名が401 `github_webhook_signature_invalid` になることを確認する。
10. 証跡を `docs/review/` へ保存する。

## 緊急rotation

漏えい疑いがある場合はprevious secretを設定しない。

1. GitHub App側のwebhook secretを即時変更する。
2. production secret storeの `GITHUB_WEBHOOK_SECRET` を新secretへ更新する。
3. `GITHUB_WEBHOOK_PREVIOUS_SECRET` が空であることを確認する。
4. deployする。
5. 旧secret署名が401で拒否されることを確認する。
6. 必要ならGitHub deliveryを手動再送する。
7. 影響範囲、拒否件数、再送結果、対応者を `docs/review/` へ保存する。

## Release Gate

planned rotation前:

- `GITHUB_WEBHOOK_SECRET` が設定されている。
- `GITHUB_WEBHOOK_PREVIOUS_SECRET` は旧secretで、currentと同一ではない。
- overlap開始時刻、終了予定時刻、承認者、rollback ownerが記録されている。
- request specでcurrent / previous secret検証が通っている。

steady state:

- `GITHUB_WEBHOOK_PREVIOUS_SECRET` が未設定である。
- `github_webhook_secret_not_configured` がproductionで発生していない。
- `github_webhook_signature_invalid` がbaselineを超えていない。

## Rollback

GitHub App側の切替後に新secret deliveryが失敗する場合:

1. GitHub App側を旧secretへ戻す。
2. app側の `GITHUB_WEBHOOK_SECRET` を旧secretへ戻す。
3. 新secretを `GITHUB_WEBHOOK_PREVIOUS_SECRET` に残すかは、失敗原因が漏えいでない場合だけ検討する。
4. delivery再送を実施し、成功を確認する。
5. rollback理由と終了条件を記録する。

## Evidence

保存する証跡:

- 実施日時
- environment
- commit SHA
- operator
- approver
- rollback owner
- overlap開始/終了
- current / previousの存在確認。値は保存しない
- local / CI / staging smoke結果
- GitHub delivery結果
- safe error code
- conclusion
