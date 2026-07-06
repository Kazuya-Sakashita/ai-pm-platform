# stale下流ドラフト再生成UX 実装レビュー

## 評価日時

2026-07-07 07:18 JST

## 評価担当

Codex / Product Manager / Tech Lead / Backend Architect / Frontend Architect / Security Engineer / QA / UI/UX Designer

外部AIレビュー: Claude、ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## Issue番号

GitHub Issue #68 / ISSUE-051: stale後の下流Draft再生成UXを実装する

## 対象

Requirement再編集後に `stale` になったIssue DraftとOpenAPI Draftを、安全に再生成へ戻すUI、APIガード、テスト。

## 使用フレームワーク

- G-STACK
- ISO25010
- STRIDE
- WCAG
- MoSCoW

## 良かった点

- Issue/OpenAPI Draftパネルに再生成案内を追加し、chipだけに依存しない状態説明にした。
- stale状態のIssue Draft保存、承認、GitHub公開、OpenAPI Draft保存、検証をUIで無効化した。
- Backendでもstale Draftの更新、公開、OpenAPI検証を409 `stale_draft` で拒否し、API直叩きによる迂回を防いだ。
- OpenAPIへ409 Conflictを追加し、Frontend生成型も同期した。
- 再承認後に新しいIssue DraftとOpenAPI Draftを生成でき、既存stale Draftを上書きしないことをRequest specで確認した。
- Playwrightでstale案内、ボタン無効化、再承認後の再生成復帰まで確認した。

## 改善点

- stale化の原因となったRequirement差分の時系列表示は未実装であり、監査体験はまだ弱い。
- 公開済みGitHub Issueがstale化した場合の差分コメント、更新PR、追跡ポリシーは未設計である。
- 複数端末で別ユーザーがRequirementを更新した場合のリアルタイム再取得や競合通知は未実装である。
- Backendの `stale_draft` は共通エラーコードとして導入したが、エラーコード一覧の専用enum化は未対応である。

## 優先順位

| 優先度 | 項目 | 状態 |
| --- | --- | --- |
| P0 | stale Draftの保存、承認、検証、公開を止める | 完了 |
| P0 | API直叩きのstale迂回を止める | 完了 |
| P1 | 再承認後に新Draftへ戻れる導線を確認する | 完了 |
| P1 | 既存stale Draftを失わないことを確認する | 完了 |
| P1 | Requirement差分履歴タイムライン | ISSUE-050へ継続 |
| P2 | 公開済みGitHub Issueの差分反映設計 | 別Issue候補 |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | stale下流Draftを誤って次工程へ進めず、再承認後に再生成へ戻せるようにする |
| Strategy | UIとAPIの両方でstale操作を止め、既存Draftを保持したまま新Draft生成へ誘導する |
| Tactics | 再生成案内パネル、ボタン無効化、Controllerガード、PublishGateガード、409契約、Request spec、Playwright |
| Assessment | 対象RSpec、zeitwerk、OpenAPI検証、Frontend build、display check、Playwrightが通過 |
| Conclusion | ISSUE-051の中核導線としてマージ可能 |
| Knowledge | 差分履歴と公開済みIssue追跡は別責務として分離する方が安全 |

## STRIDE / WCAG / ISO25010評価

- Spoofing: 対象外。
- Tampering: API直叩きでstale成果物を承認済みに戻す経路を409で遮断した。
- Repudiation: 既存AuditLogのstale対象IDと新規生成AuditLogにより、経緯を追跡できる。
- Information Disclosure: エラーdetailsはDraft ID、Requirement ID、status、actionに限定し、本文やsecretを返さない。
- Denial of Service: 追加ガードは定数時間のstatus判定であり、負荷影響は小さい。
- Elevation of Privilege: 既存認可後に状態ガードを適用し、権限保持者でもstale成果物を次工程へ進められない。
- WCAG: aria-label付きの案内パネルとテキスト説明により、色やchipだけに依存しない。
- ISO25010: 信頼性、使用性、保守性、セキュリティの改善に該当する。

## 検証結果

- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/requests/api/v1/issue_drafts_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb`: 41 examples, 0 failures
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功。Redocly CLIのNode version warningは既存の非ブロッキング警告
- `npm run display:check`: Display labels OK
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`: 1 passed

## 次アクション

1. ISSUE-050でRequirement差分履歴とレビュー履歴タイムラインを設計、実装する。
2. 公開済みGitHub Issueがstale化した場合の追跡更新方針をIssue化する。
3. 外部AIレビューが利用可能になったら、UI/APIガードの妥当性を比較レビューする。

## 判定

ISSUE-051の中核要件は完了としてよい。世界レベルSaaS基準では、差分履歴、公開済みIssue追跡、複数端末競合通知が残るため、次はISSUE-050を優先する。
