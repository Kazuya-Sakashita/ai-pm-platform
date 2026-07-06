# Requirement差し戻し時の下流ドラフトstale化 実装レビュー

## 評価日時

2026-07-07 06:58 JST

## 評価担当

Codexレビュー統括 / Product Manager / CTO / Tech Lead / Backend Architect / Frontend Architect / Security Engineer / QA

外部AIレビュー: Claude、ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- DDD
- ISO25010
- STRIDE
- MoSCoW

## 対象

承認済みRequirementのレビュー対象フィールドが再編集された場合、既存のIssue DraftとOpenAPI Draftを `stale` にして、古い下流成果物を誤って公開または採用しないようにする実装。

## 良かった点

- OpenAPI、Backend model、Frontend生成型を同期し、Issue/OpenAPI Draftの `stale` statusを契約上明示した。
- `RequirementRevisionService` 内で承認リセットと下流Draft stale化を同じトランザクションにまとめ、Controllerの肥大化を避けた。
- AuditLog metadataにstale化したIssue/OpenAPI DraftのIDと件数を保存し、後追い調査できるようにした。
- Frontendは下流Draftを消さず、画面上で「再確認が必要」と表示するため、ユーザーが古い成果物の存在を把握できる。
- RSpecとPlaywrightで、Backend状態遷移とFrontend表示の両方を確認した。

## 改善点

- stale化後の差分比較、再生成、既存GitHub Issueへの差分反映までは未実装。
- Issue Draftがpublishedだった場合もstatusはstaleになるが、既存GitHub Issue URLは残る。公開済みIssueの追跡更新は別途設計が必要。
- Frontendは現在のstateをstale表示へ切り替えるが、別端末での更新を自動再取得する仕組みはまだない。
- 外部AIレビュー比較は未実施であり、L3比較レビューとしては未完了。

## 優先順位

| 優先度 | 指摘 | 改善案 |
| --- | --- | --- |
| P0 | 古い下流成果物が承認済みのように見える問題は解消 | PR CIとmain CIで全体回帰を確認する |
| P1 | stale後の再生成/差分導線がない | Requirement差分履歴と下流Draft再生成UXを次作業にする |
| P1 | 公開済みGitHub Issueの差分反映が未設計 | GitHub Issue update方針と監査ログをADR化する |
| P2 | 別端末更新の反映 | Draft詳細の再取得導線または一覧APIを検討する |

## 次アクション

1. PR CIでbackend spec、OpenAPI、表示チェック、frontend build、Playwrightを確認する。
2. main反映後にGitHub Issue #3へ同期コメントを追加する。
3. 次のIssue #3作業として、Requirement差分履歴またはOpenAI provider比較を優先順位付けする。

## Issue番号

- GitHub Issue: #3

## 検証結果

- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/services/requirement_revision_service_spec.rb spec/requests/api/v1/requirements_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb`: 52 examples, 0 failures
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功。RedoclyのNode version warningは既存の非ブロッキング警告
- `npm run display:check`: Display labels OK: 86 messages, 53 statuses, 5 targets
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`: 1 passed

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Requirement再編集後に、古いIssue/OpenAPI Draftが最新成果物として扱われるリスクを防ぐ |
| Strategy | 承認リセット時に下流Draftをstaleへ更新し、UIと監査ログへ反映する |
| Tactics | status enum追加、Service Object、AuditLog metadata、RSpec、Playwright |
| Assessment | P0の鮮度管理は解消。差分履歴と再生成UXは継続課題 |
| Conclusion | Issue #3の下流Draft stale化としてPR化してよい |
| Knowledge | AI PMの品質は生成精度だけでなく、入力変更後の成果物鮮度を正しく管理できるかに左右される |

## 判定

実装はPR化してよい。世界レベルSaaS基準では、stale後の差分比較、再生成、公開済みGitHub Issue更新の設計が不足しているため、Issue #3は継続する。
