# GitHub Callback State Consumption ADR Review

## 評価日時

2026-07-04 13:08 JST

## 評価担当

Codex / CTO / Tech Lead / Backend Architect / Security Engineer / QA / Product Manager

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、Codex一次レビューとして保存する。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010

## Issue番号

- ISSUE-004
- GitHub Issue #4

## 良かった点

- `ADR-0011` で、GitHub callback失敗時もconnection stateを一回限りとして消費する方針を明文化した。
- ユーザー再試行性よりも、callback replay防止、CSRF境界、監査説明性を優先する判断を残した。
- 失敗種別ごとの消費/非消費を表にし、署名不正、期限切れ、nonce不一致、GitHub検証失敗、権限不足、保存失敗の扱いを整理した。
- request specでGitHub installation verification失敗後にstateが消費済みになり、同じstateの再送がGitHub API照合前に拒否されることを明示した。
- raw state、nonce raw value、GitHub raw response、tokenを保存しない方針を再確認した。

## 改善点

- callback failureをAuditLogへ明示記録する実装はまだない。
- FrontendにGitHub callback失敗画面と再接続導線がないため、ユーザー体験は未完成。
- 認証/認可が未実装のため、接続開始者とcallback attemptの操作者を紐付けられない。
- live GitHub App credentialでのconnect failure/success smokeは未実施。
- state失敗件数やreplay拒否件数の運用メトリクスは未整備。

## 優先順位

- P0: request specでstate失敗時消費とreplay拒否を固定する。
- P0: Issue #4へADR作成と残タスクを同期する。
- P1: callback failureをAuditLogへ記録する。
- P1: Frontend callback失敗画面と再接続導線を追加する。
- P1: live GitHub App credentialでconnect success/failure smokeを行う。
- P2: state replay拒否件数を運用メトリクス化する。

## 次アクション

- 対象request specを実行し、ADRと実装期待値が一致していることを確認する。
- Issue #4とGitHub Issueへ結果を同期する。
- 次の実装候補はcallback failure AuditLog、またはFrontend再接続導線とする。

## G-STACK

### Goal

GitHub App callbackのstate消費方針を明確化し、失敗時の安全性と再試行UXの境界を決める。

### Strategy

stateはCSRF/replay防止の一回限りトークンとして扱い、GitHub検証後の成否に依存させない。

### Tactics

- ADRで消費/非消費の条件表を作る。
- 現行実装の処理順序がADRに沿っていることを確認する。
- request specでGitHub verification失敗後のreplay拒否を固定する。
- Issue台帳へADRと残タスクを同期する。

### Assessment

安全性と説明可能性は改善した。一方で、callback failure auditと再接続UXが未実装のため、ユーザーが失敗から回復する体験はまだ弱い。

### Conclusion

callback失敗時のstate消費方針は決定済みとして扱える。Issue #4の「callback失敗時state消費ADR」は完了。ただしlive smoke、callback failure audit、Frontend再接続UXが残るためIssue #4はクローズ不可。

### Knowledge

state消費をGitHub検証成功後まで遅らせるとUX上は再送しやすいが、callback endpointへのreplay、並行callback、rate limit、監査説明性のリスクが増える。MVPでは新しいstateを発行し直す方が安全で単純である。

## STRIDE / OWASP確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | 署名stateとnonce消費でなりすましを抑制 | live callback payloadで確認 |
| Tampering | state改ざんは署名検証で拒否 | state digestを監査ログと関連付ける |
| Repudiation | 成功時のAuditLogはあるが失敗時記録が弱い | callback failure AuditLogを追加 |
| Information Disclosure | raw state、nonce、tokenを保存しない方針 | safe detailの日本語化を進める |
| Denial of Service | replayはGitHub API照合前に拒否 | connect/callback rate limitをIssue #6で扱う |
| Elevation of Privilege | project/repository固定はあるが認証未接続 | 認証/認可導入後に接続権限を検証 |

## 検証結果

- `bundle exec rspec spec/requests/api/v1/integration_accounts_spec.rb spec/services/github_integration/connection_state_spec.rb`: 11 examples, 0 failures

## Issue番号

- ISSUE-004
- GitHub Issue #4
