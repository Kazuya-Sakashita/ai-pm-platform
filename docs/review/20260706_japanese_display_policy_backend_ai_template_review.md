# 日本語表示ポリシー Backend安全文言・AI生成テンプレート実装レビュー

## 評価日時

2026-07-06 19:26:13 JST

## 評価担当

Codex / Product Manager / Frontend Architect / Backend Architect / AI Architect / Security Engineer / QA / UI/UX Designer

外部AIレビュー: Claude/ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- HEART
- ISO25010
- WCAG
- STRIDE

## Issue番号

ISSUE-021 / GitHub #21

## 対象

- `frontend/lib/display-labels.ts`
- `scripts/check-display-labels.rb`
- `backend/app/services/minutes_generation/*`
- `backend/app/services/conversation_summary_generation/openai_provider.rb`
- `backend/app/services/requirement_generation/deterministic_provider.rb`
- `backend/app/services/issue_draft_generation/deterministic_provider.rb`
- `backend/app/services/open_api_draft_generation/deterministic_provider.rb`
- 関連RSpec

## 良かった点

- Backendの `safe_detail`、`safe_error_detail`、`render_error`、GitHub公開ゲート、手動照合エラーを `display:check` の検査対象へ追加し、ユーザー表示に英語が漏れるリスクを下げた。
- `messageLabels` を52件から86件へ拡張し、OpenAI、GitHub App、GitHub公開照合、Issue/Requirement/OpenAPI生成ゲート、運用/レビューAPIの主要エラーを日本語表示できるようにした。
- Issueドラフト、要件定義、OpenAPIドラフト、議事録の生成テンプレートを日本語標準へ寄せた。
- OpenAI向けプロンプトを日本語標準へ変更し、入力が明確に別言語でない限り日本語で出力する方針を明示した。
- API enum、status、schema名、path、labelなど機械処理に必要な英語値は維持し、表示層との責務分離を保った。
- RSpecで日本語生成テンプレートの期待値を更新し、回帰検知できるようにした。

## 改善点

- `display:check` のAI生成テンプレート検出は、既知の英語テンプレート回帰検知が中心であり、全ての任意英語文を意味的に検出するものではない。
- GitHub APIなど外部providerが返す動的な英語メッセージは、fallback文言を日本語表示できても、provider生メッセージの完全翻訳までは保証していない。
- 狭幅スクリーンショット、支援技術確認、視覚回帰確認は今回の範囲外であり、世界レベルSaaS基準ではP2の継続改善として残る。
- 外部AIレビュー比較は未実施で、複数AIによる差分分析は次回以降のレビュー強化対象である。

## 優先順位

| Priority | 指摘 | 改善案 |
| --- | --- | --- |
| P1 | Backend安全文言の翻訳登録漏れ | `display:check` でBackend表示対象メッセージを検査し、未登録なら失敗させる |
| P1 | AI生成テンプレートの英語残存 | 既知の英語テンプレートを検査対象にし、生成物本文は日本語見出しへ変更する |
| P2 | 動的providerメッセージの翻訳限界 | provider raw messageを直接出さず、safe fallback優先にする運用を継続する |
| P2 | 視覚・支援技術確認不足 | 代表画面の狭幅スクリーンショットとアクセシビリティ確認を別Issueで扱う |
| P2 | 外部AIレビュー未実施 | 外部AIレビューが可能になった時点で比較レビューを追記する |

## 次アクション

- ISSUE-021はクローズ候補。GitHub Issueへ実装内容と検証結果をコメントし、CI成功後にクローズする。
- 今後の表示文言追加時は `npm run display:check` を必須確認とする。
- 視覚回帰、支援技術確認、外部AIレビュー比較はP2継続改善として扱う。

## 検証結果

- `npm run display:check`: 成功（86 messages、53 statuses、5 targets）
- `npm run api:verify`: 成功
- `npm run frontend:build`: 成功
- `bundle exec rspec spec/services/issue_draft_generation_service_spec.rb spec/services/requirement_generation_service_spec.rb spec/services/open_api_draft_generation_service_spec.rb spec/services/minutes_generation/openai_provider_spec.rb spec/services/conversation_summary_generation/openai_provider_spec.rb`: 15 examples、0 failures
- `bundle exec rspec spec/services/issue_draft_publish_gate_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/services/github_issue_publish/manual_reconciliation_service_spec.rb spec/services/github_issue_publish/github_app_provider_spec.rb spec/services/github_integration/installation_verifier_spec.rb`: 48 examples、0 failures

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | 日本語運用プロダクトとして、ユーザーが読むエラーと生成物を日本語で理解できる状態にする |
| Strategy | API物理値は維持し、表示変換と生成テンプレートを日本語化する |
| Tactics | `messageLabels` 拡張、`display:check` 拡張、生成provider更新、関連spec更新 |
| Assessment | #21のP1完了条件は満たした。P2の視覚回帰と外部AIレビューは継続改善として分離可能 |
| Conclusion | ISSUE-021はCI成功後にクローズしてよい |
| Knowledge | 日本語統一はUIコピーだけでなく、safe error、公開ゲート、AI生成物、プロンプトまで含めて管理する必要がある |

## 判定

合格。

ISSUE-021は、Backend安全文言とAI生成テンプレートのP1ギャップが解消されたため、CI成功後にクローズ可能である。
