# ADR-0008: GitHub Search retry/backoffとincomplete resultsの安全方針

## Status

Accepted

## Date

2026-07-02

## Context

AI PM Platformは、GitHub Issue publish後の曖昧失敗を復旧するため、AI PM markerをGitHub Search APIで検索する。これは二重Issue作成を防ぐための重要な安全機構である。

一方で、GitHub Search APIには以下の運用制約がある。

- Search APIは通常のREST API rate limitとは別枠で制限される。
- GitHub公式ドキュメントでは、authenticated searchはcode searchを除き最大30 requests/minute、unauthenticated searchは最大10 requests/minuteとされている。
- secondary rate limitでは、`retry-after`、`x-ratelimit-reset`、最低1分待機、指数backoff、上限付きretryが求められる。
- 制限中にリクエストを続けるとintegration停止リスクがある。
- Search APIはtimeout時に `incomplete_results=true` を返す場合があり、この時点では結果が完全であるとは限らない。
- GitHub Search indexing delayにより、作成直後のIssueがすぐ検索できない可能性がある。

参照:

- [GitHub REST API rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)
- [GitHub REST API best practices](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api)
- [GitHub REST API search endpoints](https://docs.github.com/en/rest/search/search)

世界レベルのSaaSとしては、rate limit時に無制限retryしないこと、検索が不完全な結果を自動判断に使わないこと、監査ログと人間レビューで復旧できることが必要である。

## Decision

MVPでは以下の方針を採用する。

1. Reconciliation APIの同期実行では、GitHub marker searchを無制限retryしない。
2. Search APIの `incomplete_results=true` は安全でない検索結果として扱い、候補が1件でも自動reconcileしない。
3. `incomplete_results=true` の場合は `github_publish_reconciliation_incomplete_results` としてReview blockerへ止める。
4. 人間レビューでは、見えている候補を参考表示しつつ、GitHub上で手動確認してから手動linkまたはcontrolled retryを選ぶ。
5. `429`、rate limit系 `403`、secondary rate limit、`503`、network timeoutは、将来の非同期jobでのみ制御付きretry対象にする。
6. controlled retryは、GitHub Searchが完了している、またはレビュアーがGitHub上でIssue未作成を確認した場合だけ許可する。
7. Search retryの状態、待機理由、次回実行可能時刻は監査対象にする。

## Retry and Backoff Policy

将来の非同期reconciler jobでは、以下の優先順で待機時間を決める。

| Failure | Retry | Backoff |
| --- | --- | --- |
| `200` + `incomplete_results=false` + 1 match | no | 自動reconcile |
| `200` + `incomplete_results=false` + 0/multiple matches | no | Review blocker |
| `200` + `incomplete_results=true` | yes, but controlled | 60秒以上待機してmarker search再実行。自動reconcileは禁止 |
| `429` or primary rate limit `x-ratelimit-remaining=0` | yes | `x-ratelimit-reset` まで待機し、jitterを加える |
| secondary rate limit with `retry-after` | yes | `retry-after` 秒待機 |
| secondary rate limit without `retry-after` | yes | 最低60秒、その後120秒、240秒の指数backoff |
| `503` / transient network error | yes | 15秒、60秒、180秒の指数backoff + jitter |
| `401` token expired | yes | installation token再発行後に1回だけ再試行 |
| `403` permission denied / installation revoked | no | reconnectまたはpermission修正 |
| `404` repository not found | no | repository設定またはconnection確認 |
| `422` validation failed / spam detection | no | queryまたは運用を見直し、人間レビュー |

最大retry回数:

- incomplete results: 2
- primary/secondary rate limit: 3
- 5xx/network: 3
- token expired: 1

上限を超えた場合はReview blockerへ止め、Issue Draftの再publishは許可しない。

## Incomplete Results Policy

`incomplete_results=true` は、GitHubがtimeout前に見つけた結果だけを返している可能性がある状態として扱う。

したがって、MVPでは以下を禁止する。

- 1件候補が見えているだけで自動reconcileすること
- `score` が高い候補を正解として扱うこと
- controlled retryで即座に新規Issueを作成すること

許可する操作:

- 候補をUIに表示する
- `検索未完了` としてレビュアーへ明示する
- レビュアーがGitHub上で確認したうえで既存Issueへ手動linkする
- cooldown後にmarker searchを再実行する

## Indexing Delay Policy

GitHub Issue作成直後にmarker searchで0件になる場合、即時controlled retryはしない。

理由:

- GitHub上にはIssueが作成済みだが、search indexにまだ反映されていない可能性がある。
- 即時retry createは二重Issue作成リスクを上げる。

MVPでは0件時にReview blockerへ止め、レビュアーへ「GitHub上でIssue未作成を確認してからcontrolled retry」を求める。将来は非同期jobで60秒以上待ってから最大2回までmarker searchを再実行する。

## Observability and Audit

以下を安全な監査メタデータとして保存または返却してよい。

- `search_total_count`
- `search_incomplete_results`
- `search_result_limit`
- `search_has_more_results`
- safe error code
- safe error detail
- retry attempt count
- next retry at
- rate limit reset at
- retry-after seconds

保存しない:

- installation access token
- Authorization header
- GitHub raw response全文
- Idempotency-Key生値
- secretを含む可能性があるIssue本文全文

## UX Requirements

Frontendは以下を満たす。

- `incomplete_results=true` の場合、検索未完了を明示する。
- retry可能な場合、再検索可能時刻または待機理由を表示する。
- controlled retryは通常ボタンではなく、レビュアー確認を伴う危険操作として扱う。
- 0件、複数件、不完全検索、rate limitを同じ文言で潰さない。
- 候補が1件でも、検索未完了なら自動解決済みのように見せない。

## Consequences

### Positive

- 不完全なGitHub Search結果で誤った自動紐付けをしない。
- rate limit時に無制限retryしてGitHub integration停止リスクを上げない。
- indexing delayによる二重Issue作成を避けられる。
- 人間レビューと監査ログの責任境界が明確になる。

### Negative

- `incomplete_results=true` では、実際に候補が1件だけでも自動復旧できない。
- 非同期retry job、retry metadata、cooldown UIの追加実装が必要になる。
- 復旧までの時間が伸びる可能性がある。

## Alternatives Considered

### `incomplete_results=true` でも1件なら自動reconcileする

不採用。

理由:

- timeout前に返った1件であり、実際には複数候補が存在する可能性を排除できない。
- 誤リンクは監査台帳の信頼性を壊す。

### 同期API内で即時3回retryする

不採用。

理由:

- ユーザー操作中に待機時間が長くなる。
- 複数ユーザー/複数Issueで同時にrate limitを悪化させる。
- retry状態の監査が弱くなる。

### rate limitをすべてFrontend操作で解決させる

不採用。

理由:

- ユーザーが再検索を連打するとsecondary rate limitを悪化させる。
- retry/backoffはBackend jobとして統制すべきである。

## Implementation Follow-up

- [Done 2026-07-02] `incomplete_results=true` では候補1件でも自動reconcileしない。
- [Done 2026-07-02] GitHub response headersから `retry-after`、`x-ratelimit-remaining`、`x-ratelimit-reset` をsafe metadataへ反映する。
- [Done 2026-07-02] Reconciliation attemptにretry count、next retry at、cooldown状態を保存する。
- [Done 2026-07-02] Frontendに再検索可能時刻を表示し、cooldown中のmarker searchとcontrolled retryを停止する。
- [Done 2026-07-03] ActiveJobの `GithubIssuePublish::ReconciliationRetryJob` でcooldown後のmarker searchを自動実行する。
- [Done 2026-07-03] production向け永続Job基盤をADR-0010でSolid Queue採用方針として決定する。
- [Todo] live GitHub App credentialでrate limitではない通常search smokeを行う。
- [Todo] sandbox/stagingでrate limit headerのsafe handlingをモックまたはrecordingで検証する。
