# GitHub Callback Failure Audit and Reconnect UI Review

## 評価日時

2026-07-04 17:24 JST

## 評価担当

Codex / CTO / Tech Lead / Backend Architect / Frontend Architect / Security Engineer / QA / UI/UX Designer / Product Manager

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、Codex一次レビューとして保存する。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- WCAG
- ISO25010

## Issue番号

- ISSUE-004
- GitHub Issue #4

## 良かった点

- GitHub callbackでinstallation verificationに失敗した場合、`github.connect.failed` AuditLogを保存するようにした。
- 失敗AuditLogのmetadataはrepository、setup_action、installation id、safe error code/detailに限定し、raw stateやnonceを保存しないことをrequest specで固定した。
- AuditLog保存失敗がcallback error responseを潰さないよう、監査ログ保存失敗はRails logへ退避する形にした。
- ワークスペース左側へGitHub連携状態パネルを追加し、未接続、接続済み、エラー、解除済みを日本語表示できるようにした。
- GitHub未接続による公開失敗パネルから、同じ画面内で `GitHub連携を開始` / `GitHub接続をやり直す` を実行できる導線を追加した。
- GitHub App installation URLは自動遷移せず、生成後にユーザーが `GitHub App設定を開く` リンクを押す形にし、予期しない画面遷移を避けた。
- `display-labels.ts` へGitHub連携statusとsafe messageの日本語表示を追加し、内部enumと表示文言を分離した。
- Playwright mock E2Eで、pending reconciliation導線がGitHub連携状態API追加後も動くことを確認した。

## 改善点

- GitHubから戻る専用callback result pageは未実装であり、callback成功/失敗後にユーザーへ明確な画面を出すには追加実装が必要。
- `github.connect.failed` はProject AuditLogへ保存しているが、失敗件数の運用メトリクスや監視アラートは未実装。
- callback state不正や期限切れなど、Projectを信頼できない失敗はProject AuditLogへ保存しないため、将来security audit logの設計が必要。
- GitHub App実credentialでのconnect success/failure smokeは未実施。
- 再接続ボタンはinstallation URL生成までであり、GitHub側の実インストール完了確認はlive smoke待ち。
- 接続解除、権限更新、installation revoked同期はまだUI/Backendともに未完了。

## 優先順位

- P0: callback failure AuditLogをrequest specで固定する。
- P0: Frontend buildと表示ラベルチェックを通し、再接続導線が型と日本語表示を壊していないことを確認する。
- P0: Issue #4へcallback failure AuditLogと再接続導線の完了範囲を同期する。
- P1: GitHub callback専用の成功/失敗result pageを追加する。
- P1: live GitHub App credentialでconnect success/failure smokeを行う。
- P1: callback failure件数を監視対象にする。
- P2: disconnect/reconnect/permission updateの運用UIを整える。

## 次アクション

- Issue #4とGitHub Issueへ実装結果と残タスクを同期する。
- 次に進めるcredential不要タスクとして、staging/production worker smoke runbookまたはGitHub callback result pageを検討する。
- live GitHub App smokeは、GitHub App設定とcallback到達URLが準備できてから実施する。

## G-STACK

### Goal

GitHub接続失敗時に、ユーザーが再接続でき、運用者が安全に原因を追える状態にする。

### Strategy

Backendはsafe metadataのみをAuditLogへ保存し、FrontendはGitHub連携状態と再接続アクションをワークスペース内へ表示する。

### Tactics

- `github_callback` の `GithubIntegration::VerifierError` rescueで `github.connect.failed` を記録する。
- request specでmetadataにraw state/nonceが含まれないことを確認する。
- `GET /projects/{project_id}/integrations` をFrontendから読み込み、GitHub連携状態を表示する。
- `POST /projects/{project_id}/integrations/github/connect` をFrontendの再接続ボタンへ接続する。
- 未接続publish failure panelに再接続アクションを追加する。
- 表示ラベルとPlaywright E2Eを更新する。

### Assessment

監査可能性とユーザー回復性は前進した。特にlive smoke前に失敗AuditLogを入れたことで、実credential検証時の調査しやすさが上がった。一方で、GitHub Appから戻る専用画面と実credential smokeがないため、接続フロー全体のUXはまだ完成ではない。

### Conclusion

callback failure AuditLogとワークスペース内の再接続導線はMVP実装済み。ただしIssue #4はlive GitHub App smoke、callback result page、staging worker smoke、queue監視が残るためクローズ不可。

### Knowledge

GitHub App連携は外部画面遷移を伴うため、UIで自動遷移しすぎるとユーザーが状態を見失いやすい。MVPではinstallation URLを生成してリンクとして提示し、再接続操作と監査ログを明確に分ける方が安全である。

## STRIDE / OWASP確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | state検証後のGitHub verification失敗を安全に記録 | live callback payloadで実証 |
| Tampering | raw state/nonceをAuditLogへ保存しない | state digest連携は将来検討 |
| Repudiation | `github.connect.failed` で失敗証跡が残る | callback result pageと操作者IDを追加 |
| Information Disclosure | token、raw response、stateを保存しない | safe detailの日本語化範囲を継続整理 |
| Denial of Service | 再接続ボタンは新しいstateを発行するだけ | connect/callback rate limitをIssue #6で扱う |
| Elevation of Privilege | project/repository固定は維持 | 認証/認可導入後に接続権限を検証 |

## WCAG / UX確認

- GitHub連携パネルは `aria-label="GitHub連携"` を持ち、状態chipとボタンを読み取れる。
- 公開失敗パネル内の再接続アクションは `aria-label="GitHub再接続"` を持つ。
- ボタン文言は日本語で、状態が接続済みの場合は `GitHub接続をやり直す` として危険操作に見えすぎない表現にした。
- ただし専用callback result pageとスクリーンリーダー実機確認は未実施。

## 検証結果

- `bundle exec rspec spec/requests/api/v1/integration_accounts_spec.rb spec/requests/api/v1/audit_logs_spec.rb`: 9 examples, 0 failures
- `bundle exec rspec`: 150 examples, 0 failures
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- `npm run display:check`: Display labels OK
- `npm run frontend:build`: success
- `npm run frontend:e2e -- --grep "shows pending GitHub reconciliation controls"`: 1 passed
- `git diff --check`: pass

## Issue番号

- ISSUE-004
- GitHub Issue #4
