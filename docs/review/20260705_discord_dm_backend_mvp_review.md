# Discord DM手動インポートBackend MVP実装レビュー

## 評価日時

2026-07-05 02:01 JST

## 評価担当

Codex / CTO / Tech Lead / Backend Architect / AI Architect / Security Engineer / QA

## Issue番号

ISSUE-022

## 使用フレームワーク

- G-STACK
- DDD
- STRIDE
- OWASP Top 10
- ISO25010

## 対象

- Conversation Import API
- Conversation Summary Draft API
- scan service
- deterministic summary generation service
- DB migration / model / request spec

## 良かった点

- 既存OpenAPI契約に合わせて、Conversation ImportとConversation Summary DraftのBackend最小sliceを実装した。
- ControllerはHTTP受付、認可前提のリソース取得、レスポンス返却に限定した。
- scan処理は `ConversationImports::ScanService`、整理生成は `ConversationSummaryGenerationService` と deterministic providerへ分離した。
- 同意未確認とsecret-like contentをAI整理前にblockedへ止められるようにした。
- AuditLogには本文全文を保存せず、valid、件数、blocked reason、job idなどのsafe metadataへ限定した。
- raw text変更時に未承認summary draftをstaleに戻す導線を入れた。
- raw/redacted text変更時にimport statusを `draft` へ戻し、再scanなしでAI整理へ進めないようにした。
- `redacted_text` をAI整理入力として優先し、raw secretがsummary draft responseへ混入しないことをrequest specで固定した。
- OpenAPIで必須の `approval_note` をBackendでも必須化し、承認理由なしのapproveを拒否するようにした。
- RSpecでcreate/list/scan/generate/update/approveの主要API導線を固定した。

## 改善点

- 実AI providerは未接続であり、deterministic整理はMVP placeholderである。
- raw textは平文DB保存であり、本番前に暗号化、retention、削除/匿名化方針のADRが必要である。
- 認証ユーザー/権限がないため、`imported_by`、`approved_by`、`consent_confirmed_by` は実ユーザーに紐付いていない。
- safety scanは既存secret pattern中心で、PII、金融、法務、同意粒度の検出は弱い。
- Frontend UIは未実装で、手動貼り付け、redaction、同意確認の操作体験はまだ検証できない。
- Review Centerとの正式連動、下流のRequirement/Issue変換は未接続である。

## 優先順位

- P0: Backend APIをOpenAPI契約に合わせて実装する。
- P0: 同意なし、secret-like contentありではAI整理へ進めない。
- P0: AuditLogへraw textやsecret値を保存しない。
- P0: raw/redacted text更新後は再scanを必須にする。
- P0: summary draft承認時は承認理由を必須にする。
- P1: Frontend DMインポートUIを実装する。
- P1: AI Structured Outputs providerとreview gate連動を追加する。
- P1: 暗号化、retention、削除方針をADR化する。

## 次アクション

- FrontendにDMインポート/scan/整理生成/承認UIを追加する。
- DM summary prompt/schemaを実装providerへ接続する。
- raw text保存の暗号化とretention ADRを作成する。
- PII検出とredaction suggestionを強化する。
- Review CenterとConversation Summary Draft承認を接続する。

## 検証

- `bundle exec rails db:migrate`: success
- `RAILS_ENV=test bundle exec rails db:migrate`: success
- `bundle exec rspec spec/requests/api/v1/conversation_imports_spec.rb spec/requests/api/v1/conversation_summary_drafts_spec.rb`: 12 examples, 0 failures
- `bundle exec rspec`: 165 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `git diff --check`: pass
- GitHub Actions CI `28713458334`: success（commit `c48d3b8`）

## G-STACK

### Goal

Discord DMの手動貼り付けを、同意、redaction、安全チェック、AI整理、レビュー承認へつなぐBackend基盤を作る。

### Strategy

Discord API自動取得は避け、OpenAPI済みの手動インポート契約へRails Backendを合わせる。

### Tactics

- `conversation_imports` と `conversation_summary_drafts` を追加する。
- scan serviceで同意とsecret-like contentを検査する。
- deterministic providerでAI接続前の整理導線を固定する。
- Request specで主要API contractを検証する。

### Assessment

実装はMVPとして妥当。ただし世界レベルSaaS基準では、DMは高センシティブ領域であり、暗号化、retention、同意証跡、PII redaction、権限設計なしでは本番投入できない。

### Conclusion

ISSUE-022のBackend MVPは実装済みとして扱える。Frontend、AI provider、セキュリティ強化、Review Center連動は継続課題。

### Knowledge

DM整理機能の価値は高いが、自動取得よりも「ユーザーが明示的に貼り付け、同意とredactionを確認し、人間が承認する」流れを守ることが信頼の前提である。

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPTなど外部AIレビューは未実施のため、外部レビュー結果が追加された場合は相違点を追記する。
