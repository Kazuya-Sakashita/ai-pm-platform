# GitHub Reconciliation History UI/API Review

## 評価日時

2026-07-04 08:23 JST

## 評価担当

Codex / Product Manager / CTO / Tech Lead / Backend Architect / Frontend Architect / Security Engineer / QA / UI/UX Designer

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、Codex一次レビューとして保存する。

## 使用フレームワーク

- G-STACK
- DDD
- STRIDE
- OWASP Top 10
- ISO25010
- WCAG

## Issue番号

- ISSUE-004
- GitHub Issue #4

## 良かった点

- Issue Draft APIへ直近5件のGitHub公開照合履歴を追加し、pending中の1件だけでなく、失敗、retry承認、reconcile済みの流れを追えるようにした。
- `idempotency_digest`、raw exception、free-form resolution noteをAPIへ出さず、attempt id、status、safe error、GitHub Issue URL、retry承認メタデータに限定した。
- controlled retryの承認者、理由テンプレート、理由ラベルを履歴へ反映し、運用レビューで「誰が何を根拠に再試行を許可したか」を確認しやすくした。
- Frontendに照合履歴パネルを追加し、再試行承認、GitHub作成、ローカル保存、照合済みの状態を日本語ラベルで表示できるようにした。
- GitHub照合履歴のJSON整形を `IssueDraftReconciliationHistorySerializer` へ分離し、`IssueDraft#api_json` は呼び出し口に留め、controllerとModel本体の肥大化を避けた。
- Request specとPlaywright E2Eで、機密性の高い内部値がレスポンスや画面に出ないことを確認する観点を追加した。

## 改善点

- `IssueDraft#api_json` 自体はまだModelに残っており、将来的にはIssue Draft全体のAPI serializerへ移す余地がある。
- 履歴は直近5件固定で、pagination、filter、監査ログ全文検索は未実装。
- retry承認者は自由入力であり、認証導入後のユーザーID紐付けは未実装。
- safe error detailは既存のsafe値を表示しているが、すべての文言が日本語の運用文として最適化されているわけではない。
- 実GitHub App credentialでのlive smokeが未実施のため、実API遅延、rate limit、GitHub側一時障害時の履歴可読性は未確認。
- スクリーンリーダーでの履歴読み上げ順と、狭幅viewportでの視覚確認は追加検証が必要。

## 優先順位

- P0: Request spec、OpenAPI検証、Frontend E2Eを通し、機密情報が履歴レスポンスに出ないことを確認する。
- P0: Issue #4へ今回のAPI/UI履歴追加を同期する。
- P1: 実GitHub App credentialでlive smokeを実施し、履歴が実データで追跡できるか確認する。
- P1: 認証導入後、retry承認者をユーザーID/表示名へ紐付ける。
- P2: 履歴のpagination、filter、監査ログ詳細画面を検討する。
- P2: 画面読み上げと狭幅スクリーンショット確認を追加する。

## 次アクション

- 認証導入時にretry承認者を自由入力からユーザーID/表示名へ移行する。
- 実GitHub App credentialでlive smokeを実施し、実データの履歴可読性をレビューする。
- live smoke成功まではISSUE-004をopen維持する。

## 検証結果

- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- `bundle exec rspec spec/requests/api/v1/issue_drafts_spec.rb`: 25 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run display:check`: Display labels OK
- `FRONTEND_URL=http://localhost:3002 NEXT_PUBLIC_API_BASE_URL=http://localhost:3003/api/v1 npm run frontend:e2e -- --grep 'creates a project'`: 1 passed
- `FRONTEND_URL=http://localhost:3002 NEXT_PUBLIC_API_BASE_URL=http://localhost:3003/api/v1 npm run frontend:e2e`: 14 passed
- `npm run frontend:build`: success

## G-STACK

### Goal

GitHub公開に失敗した後の復旧判断と監査を、1回限りのpending状態ではなく履歴として追跡できるようにする。

### Strategy

既存のpublish attempt tableとAuditLogを活かし、APIレスポンスは安全な要約に限定する。画面は追加パネルに留め、復旧操作そのものの導線は既存UIを維持する。

### Tactics

- 直近5件のattemptを `IssueDraftReconciliationHistorySerializer` で整形する。
- retry承認メタデータはAuditLogからattempt idで紐付ける。
- OpenAPIと生成型を更新する。
- Frontendへ照合履歴パネルを追加する。
- Request specとE2Eで安全な表示範囲を確認する。

### Assessment

監査性と運用可視性は前進した。ただし世界レベルSaaS基準では、actor identity、監査検索、live smoke、支援技術QAがまだ不足している。

### Conclusion

履歴表示のMVPは実装価値が高い。Issue #4は前進したが、実credential検証と認証ユーザー紐付けが残るためクローズ不可。

### Knowledge

GitHub照合履歴は業務判断の監査データであり、永続化済みattemptとAuditLogから安全なAPI表示形へ変換する責務として扱う。履歴整形は専用serializerへ閉じ込め、Issue Draft全体のserializer化はレスポンス責務がさらに増えた段階で検討する。
