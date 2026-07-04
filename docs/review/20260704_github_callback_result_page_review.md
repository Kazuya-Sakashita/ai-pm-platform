# GitHub Callback Result Page Review

## 評価日時

2026-07-04 20:38 JST

## 評価担当

Codex / CTO / Tech Lead / Frontend Architect / Security Engineer / QA / UI/UX Designer / Product Manager

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

- `/github/callback` にGitHub App setup URLから戻るためのresult pageを追加した。
- URL queryの `state`、`installation_id`、`setup_action` をFrontendが受け取り、Backendの `POST /integrations/github/callback` へ1回だけ送信するようにした。
- callback成功時は接続完了、repository、account、statusを表示し、ワークスペースへ戻れるようにした。
- callback失敗時はsafe error messageを日本語化し、ワークスペースへ戻って再接続できる導線を表示した。
- raw stateを画面へ表示しないことをPlaywright E2Eで確認した。
- 必須query parameterが不足している場合はBackendへcallback requestを送らず、安全な失敗画面を出すようにした。
- 狭幅viewportで横スクロールが発生しないことをPlaywright E2Eで確認した。
- `useSearchParams` 依存を避け、Server Componentでqueryを文字列化してClient Componentへ渡す構造にした。

## 改善点

- 実GitHub App setup URLからのcallback payloadは未検証であり、query parameter名と戻り挙動はlive smokeで確認が必要。
- callback result pageはProject名や直前の接続開始情報を表示できないため、ユーザー文脈はまだ弱い。
- 失敗後の再接続はワークスペースへ戻る導線であり、その場で新しいstateを発行する直接導線ではない。
- callback result pageのスクリーンリーダー実機確認は未実施。
- 認証/認可が未実装のため、callback完了後のユーザー権限確認はまだない。

## 優先順位

- P0: callback result pageが成功/失敗/必須parameter不足を安全に扱うことをE2Eで確認する。
- P0: raw stateを画面表示しないことをE2Eで固定する。
- P0: Issue #4へcallback result page完了と残タスクを同期する。
- P1: live GitHub App credentialでsetup URLからcallback pageへ戻る流れを確認する。
- P1: callback result pageから直接再接続を開始するUXを検討する。
- P2: callback result pageにProject名やrepository contextを表示する。

## 次アクション

- GitHub Issue #4へ実装結果と検証結果を同期する。
- 次にcredential不要で進めるなら、staging/production worker smoke runbookとqueue監視設計へ進む。
- live GitHub App smokeは、GitHub App setup URLとcallback到達URLが準備できてから実施する。

## G-STACK

### Goal

GitHub Appから戻ったユーザーに、接続成功/失敗を安全に表示し、ワークスペースへ戻れる導線を用意する。

### Strategy

Frontend callback pageは外部callback payloadを最小限受け取り、Backend callback APIへ委譲する。秘密性のあるstateは画面に出さない。

### Tactics

- `/github/callback/page.tsx` を追加する。
- Client ComponentでBackend callback APIを1回だけ呼ぶ。
- 成功時にIntegrationAccountのsafe fieldsだけ表示する。
- 失敗時は `displayMessage` で日本語safe messageを表示する。
- Playwright E2Eで成功、失敗、parameter不足をmock検証する。

### Assessment

GitHub App接続のUXは一段前進した。特に、外部callback後にユーザーが空白ページやAPI responseではなく、明確な日本語result pageを見る構造になった。一方で、live GitHub Appでの実payload確認がないため、Issue #4のlive smoke blockerは残る。

### Conclusion

callback result pageのMVPは実装済み。Issue #4の「GitHubから戻った後の成功/失敗表示」は完了扱いにできる。ただしlive GitHub App smoke、staging/production worker smoke、queue監視、認証ユーザー紐付けが残るためIssue #4はクローズ不可。

### Knowledge

GitHub App setup callbackは外部リダイレクトであり、URL上にstateが存在する。画面表示ではstateを出さず、Backendへの一回限りPOSTに閉じ込めることが安全である。

## STRIDE / OWASP確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | Backend state verificationへ委譲 | live callback payloadで確認 |
| Tampering | state改ざんはBackendが拒否 | 失敗時のsafe messageを維持 |
| Repudiation | Backend AuditLogと接続できる | callback resultからrequest id表示を検討 |
| Information Disclosure | raw stateを画面に表示しない | URL自体の扱いを運用手順に追記 |
| Denial of Service | Clientは一回だけcallback APIを呼ぶ | callback endpoint rate limitをIssue #6で扱う |
| Elevation of Privilege | 権限判断はBackendで実施 | 認証/認可導入後に権限を追加確認 |

## WCAG / UX確認

- result pageは `aria-live="polite"` で状態変化を通知する。
- 成功/失敗の見出しと本文を分け、色だけに依存しない。
- ワークスペースへ戻るリンクと失敗時の再接続導線をキーボード操作可能なリンクとして配置した。
- 狭幅viewportでは横スクロールがないことをE2Eで確認した。
- ただし実スクリーンリーダー確認とビジュアルスクリーンショットレビューは未実施。

## 検証結果

- `npm run frontend:build`: success
- `npm run display:check`: Display labels OK
- `npm run frontend:e2e -- e2e/github-callback.spec.ts`: 3 passed
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- `git diff --check`: pass

## Issue番号

- ISSUE-004
- GitHub Issue #4
