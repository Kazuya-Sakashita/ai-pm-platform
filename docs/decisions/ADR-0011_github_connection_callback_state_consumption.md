# ADR-0011: GitHub callback失敗時もconnection stateを一回限りで消費する

## Status

Accepted

## Date

2026-07-04

## Context

AI PM PlatformのGitHub App接続では、`POST /projects/{project_id}/integrations/github/connect` が署名付きstateを発行し、`POST /integrations/github/callback` がstateを検証してGitHub installationを照合する。

現在のcallback処理順序は以下である。

1. 署名付きstateを検証する
2. DBに保存したnonce digestを照合する
3. stateを `consumed_at` で消費済みにする
4. GitHub APIでinstallation、repository access、Issues write権限を確認する
5. `integration_accounts` を保存する

この順序では、GitHub installation検証や権限確認に失敗した場合でもstateは消費済みになり、同じcallback requestを再送しても成功しない。

世界レベルSaaSとしては、ユーザーの再試行性だけでなく、replay防止、CSRF耐性、監査可能性、サポート時の説明可能性を明確にする必要がある。

## Decision

GitHub callbackのconnection stateは、署名、期限、nonce、project、repositoryが一致した時点で一回限りとして消費する。

GitHub installation検証、権限確認、repository access確認、または `integration_accounts` 保存で失敗しても、同じstateは再利用させない。

失敗後の再試行は、同じcallback URLの再送ではなく、GitHub connection startからやり直して新しいstateを発行する。

## Rationale

- stateはCSRF対策とproject/repository固定の境界であり、一度callback endpointへ到達した時点でリプレイ価値が高い。
- callback失敗理由が権限不足、installation mismatch、repository mismatchの場合、同じstateを再利用しても成功する保証は低い。
- state再利用を許すと、並行callbackやブラウザ戻る操作、悪意ある再送の扱いが複雑になる。
- 新しいstateを発行し直す方が、ユーザー操作、AuditLog、サポート調査の境界が明確になる。
- 生stateは保存せずdigestだけを保存する現在方針と整合する。

## State Consumption Policy

| 状況 | state消費 | ユーザー/運用対応 |
| --- | --- | --- |
| state署名が不正 | 消費しない | 不正stateとして拒否 |
| state期限切れ | 消費しない | connection startからやり直す |
| nonce digestがDBにない | 消費しない | 不正またはcleanup済みとして拒否 |
| project/repository不一致 | 消費しない | 不正stateとして拒否 |
| 未消費stateでGitHub installation検証失敗 | 消費する | connection startからやり直す |
| 未消費stateで権限不足 | 消費する | GitHub App権限を修正してconnection startからやり直す |
| 未消費stateでrepository accessなし | 消費する | repository accessを修正してconnection startからやり直す |
| `integration_accounts` 保存失敗 | 消費する | 運用調査後、connection startからやり直す |
| callback成功 | 消費する | connectedとして保存 |
| 同じstateの再送 | すでに消費済み | `github_state_invalid` として拒否 |

## UX Requirements

- Frontendはcallback失敗時に「接続を最初からやり直す」導線を表示する。
- エラー文言はraw GitHub responseや署名stateを露出しない。
- GitHub App権限不足、repository access不足、installation検証失敗は同じ汎用エラーに潰さず、安全な日本語detailへ変換する。
- ブラウザ再読み込みで同じcallbackを再送しても成功しないことを許容し、再接続ボタンで新しいstateを作る。

## Audit and Observability

保存してよい情報:

- project id
- repository
- safe error code
- safe error detail
- callback attempt time
- consumed state record id
- installation id

保存しない情報:

- raw state
- nonce raw value
- installation access token
- GitHub raw response全文
- Authorization header

## Security Impact

### Positive

- callback replayと並行callbackのリスクを低く保てる。
- 失敗理由に関係なくstateの一回限り性が明確になる。
- state再利用を前提にした複雑な条件分岐を避けられる。
- 監査上、「このconnection attemptは終了した」と説明しやすい。

### Negative

- 一時的なGitHub API障害でもユーザーはconnection startからやり直す必要がある。
- GitHub側の設定修正後に同じcallback URLを再利用できない。
- callback失敗時のユーザー向け再接続UXがないと、操作が途切れて見える。

## Alternatives Considered

### GitHub installation検証が成功するまでstateを消費しない

不採用。

理由:

- 同じcallbackの再送がGitHub APIへ繰り返し到達し、rate limitや監査ノイズを増やす。
- 並行callback時に、複数requestが同じstateで検証処理へ進む可能性がある。
- stateの一回限り性が「どの外部検証まで成功したか」に依存し、説明が難しくなる。

### 失敗種別によって消費/非消費を分ける

不採用。

理由:

- installation mismatch、権限不足、repository access不足、GitHub一時障害を正確に分類し続ける負荷が高い。
- 一部の失敗だけ再利用を許すと、攻撃者と正規ユーザーの再送を区別しにくくなる。
- MVPでは新しいstateの発行コストが低く、複雑化する価値が小さい。

### callback失敗時にstateを自動再発行する

不採用。

理由:

- GitHub App installation flowの途中状態とAI PM Platformの接続開始状態がずれやすい。
- ユーザーに明示的な再接続操作を求めた方が、repositoryと権限の確認を促せる。

## Implementation Notes

- 現行実装は `GithubIntegration::ConnectionState.consume!` をGitHub installation verificationの前に呼ぶため、このADRに沿っている。
- request specで、GitHub installation verification失敗後にstateが消費済みになり、同じstateの再送がGitHub API照合前に拒否されることを確認する。
- 将来、認証/認可導入後はcallback attemptの操作者、接続開始者、project権限をAuditLogへ紐付ける。

## Follow-up

- [Done 2026-07-04] callback失敗時もstateを消費する方針をADR化する。
- [Done 2026-07-04] request specでGitHub installation verification失敗後のstate replay拒否を明示する。
- [Todo] Frontend callback失敗画面に再接続導線を追加する。
- [Todo] callback failureをAuditLogへ明示記録する。
- [Todo] 認証/認可導入後、接続開始者とcallback attemptを紐付ける。
