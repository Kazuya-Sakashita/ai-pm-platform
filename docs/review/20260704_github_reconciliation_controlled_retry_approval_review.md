# GitHub Reconciliation Controlled Retry Approval Review

## 評価日時

2026-07-04 05:37 JST

## 評価担当

Codex / Product Owner / CTO / Tech Lead / Security Engineer / QA / Frontend Architect

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、一次レビューとしてCodex評価を保存する。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- WCAG

## 対象

- GitHub publish reconciliation の controlled retry 承認メタデータ
- Link Issue のURL送信前検証
- OpenAPI / Rails request spec / Playwright E2E の契約同期

## 良かった点

- Goal: controlled retryに承認者と理由テンプレートを必須化し、二重Issue作成リスクの監査証跡を強化した。
- Strategy: 業務ルールを `GithubIssuePublish::ManualReconciliationService` に集約し、Controllerはpermitとresponse整形に留めた。
- Tactics: OpenAPI、生成型、Backend request spec、Frontend E2Eを同時に更新し、API駆動の契約ずれを抑制した。
- Assessment: `resolution_approver`、`retry_reason_template`、`resolution_note` がAuditLog、attempt detail、Review resolution noteへ残る。
- STRIDE: controlled retryの否認リスクを下げ、誰がどの理由で再試行を承認したか追跡できる。
- WCAG: 既存フォームのlabel/select/input構造を維持し、キーボード操作とアクセシブルnameを崩していない。

## 改善点

- 承認者入力は自由記述であり、実ユーザーID、権限、監査主体との紐付けはまだない。
- 理由テンプレートはFrontend/Backendの二重定義であり、将来テンプレート増減時の同期漏れリスクがある。
- controlled retryの承認履歴はAuditLog/attemptに残るが、UI上で履歴一覧として閲覧できない。
- Link IssueのURL検証は送信前に強化されたが、実GitHub App credentialでのlive connect/publish/reconcile smokeは未実施。
- スクリーンリーダー実機確認は未実施。PlaywrightはDOM/keyboard検証であり、読み上げ順までは保証しない。

## 改善案

- 認証導入後、`resolution_approver` を自由入力からcurrent user IDへ移行し、表示名と監査IDを分離する。
- retry reason templateをAPI responseまたは定数schemaとして配布し、Frontend/Backendの二重定義を解消する。
- Issue Draft詳細にreconciliation履歴一覧を追加し、attempt、AuditLog、Review resolutionを横断表示する。
- GitHub App credentialを使ったstaging smoke手順をrunbook化し、connect、publish、reconcile、controlled retryを確認する。
- VoiceOver等でreconciliation panelの読み上げ順、selectの候補、error alertの伝達を確認する。

## 優先順位

- P0: 実GitHub App credentialでconnect/publish/reconcile smokeを実施する。
- P0: controlled retryの承認者を将来の認証ユーザーへ紐付ける設計をADR化する。
- P1: retry reason templateの単一定義化を行う。
- P1: reconciliation履歴UIとfailed job運用UIを追加する。
- P2: スクリーンリーダー確認結果をレビューへ追記する。

## 次アクション

- ISSUE-004に本レビューと検証結果を追記する。
- GitHub Issue #4へ進捗を同期する。
- 次の実装候補は、実GitHub App live smoke、またはreconciliation履歴/failed job運用UI。

## Issue番号

- ISSUE-004
- GitHub Issue: #4

## 結論

controlled retryは、以前より監査可能性が上がり、危険な再試行を「メモだけ」で承認できる状態から一段改善した。一方で、世界レベルのSaaS基準では承認者が自由入力である点はまだ弱い。MVP段階では妥当だが、認証導入後にユーザー主体へ必ず接続する必要がある。

## 検証

- `bundle exec rspec spec/services/github_issue_publish/manual_reconciliation_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 29 examples, 0 failures
- `bundle exec rspec`: 143 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 14 passed
