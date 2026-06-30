# 2026-06-30 Requirement Approval Gate レビュー

## 評価日時

2026-06-30 18:52 JST

## 評価担当

Codex as Product Manager / Tech Lead / Backend Architect / Frontend Architect / QA / Security Engineer

外部AIレビュー: 未実施。Claude / ChatGPT 等の別AIレビューは追加待ち。

## 使用フレームワーク

- G-STACK
- MoSCoW
- ISO25010
- STRIDE
- DDD

## 良かった点

- `POST /requirements/{requirement_id}/approve` をOpenAPI、Backend、Frontend、E2Eへ接続した。
- Requirementの `open_questions` が残っている場合は409 `review_required` で承認を止め、未決事項をIssue/OpenAPI生成へ流さないゲートを追加した。
- Requirement承認時に `requirement.approved` のAuditLogを保存し、次工程へ進む根拠を監査できるようにした。
- FrontendのRequirement Workspaceから承認操作まで実行でき、PlaywrightでMinutes承認からRequirement承認までのhappy pathを確認した。
- 既存のAGENTS.mdルール「レビューなしで次工程へ進まない」を、文書だけでなくAPI状態遷移として表現した。

## 改善点

- 承認権限、actor、承認者、承認日時の専用カラムがなく、誰が承認したかはまだ弱い。
- Review recordがresolvedかどうかまでは承認条件に含めておらず、現状は `open_questions` の有無だけで判定している。
- 品質評価スコアが承認条件に接続されていない。
- 承認後の再編集時に `approved` から `needs_changes` へ戻す状態管理が未実装。
- Issue/OpenAPI生成API自体は未実装で、approved Requirementを次工程のgateとして使うところまでは未接続。

## 優先順位

1. P0: Issue/OpenAPI生成時にRequirement `approved` を必須条件にする
2. P0: Requirement品質評価baselineを取得し、承認前チェックに接続する
3. P1: Requirement承認者、承認日時、再編集時の状態遷移をDB/APIへ追加する
4. P1: Review Centerのresolved状態を承認条件へ接続する
5. P1: 未決事項、リスク、差分をRequirement Workspaceで強調表示する

## 次アクション

- RSpec、OpenAPI verify、Frontend build、Playwright E2Eを通し、GitHubへpushする。
- CI成功後、Issue #3へ承認ゲート完了と残課題を同期する。
- Issue #4へ進む前に、approved RequirementをIssue/OpenAPI生成条件へ接続する。

## Issue番号

- GitHub Issue: #3

## G-STACK

### Goal

Requirement draftを人間レビューと未決事項解消なしに次工程へ進めないようにする。

### Strategy

OpenAPI契約とAPI状態遷移にRequirement承認を追加し、Frontend/E2Eで操作可能な最小gateを作る。

### Tactics

- `/requirements/{requirement_id}/approve` をOpenAPIに追加
- Backendでopen questionsが残るRequirement承認を409でブロック
- AuditLogに `requirement.approved` を保存
- FrontendにApprove Requirementsを追加
- Playwright E2EでRequirement承認まで確認

### Assessment

レビューゲートの骨格は前進した。ただし、承認者、resolved review、品質スコアまで含めた本格gateではないため、世界レベルSaaS基準ではまだ初期実装である。

### Conclusion

条件付き合格。Issue #3のP0「Requirement承認APIとReview gate」はMVPとして完了。ただし、Issue #4へ進むにはapproved RequirementをIssue/OpenAPI生成条件に接続する必要がある。

### Knowledge

AI PMの信頼性は「生成できる」より「未決事項がある成果物を止められる」ことに強く依存する。

## MoSCoW

| 区分 | 内容 | 状態 |
| --- | --- | --- |
| Must | Requirement承認API | 完了 |
| Must | 未決事項が残るRequirement承認のブロック | 完了 |
| Must | Frontend承認操作 | 完了 |
| Must | E2Eで承認導線を確認 | 完了 |
| Should | Review resolved状態との接続 | 未完了 |
| Should | 品質評価スコアとの接続 | 未完了 |
| Could | 承認者、承認日時、再編集差分 | 未完了 |
| Won't now | 完全自動承認 | 非スコープ |

## STRIDE

| 脅威 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | actor認証がないため承認者特定が弱い | Issue #6で認証/actorを実装 |
| Tampering | 承認後に編集可能 | 再編集時の状態戻しが必要 |
| Repudiation | AuditLogはあるが承認者カラムがない | approved_by/approved_at追加を検討 |
| Information Disclosure | Requirement内容のsecret再scanはない | 生成前scanと品質評価のCritical failureで補う |
| Denial of Service | 同期処理で軽量 | background job化は後続 |
| Elevation of Privilege | 権限境界未実装 | Issue #6で対応 |

## 検証結果

- `bundle exec rspec`: 35 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功。OpenAPI contract warningなし。Node version warningのみ既知
- `npm run frontend:build`: 成功
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

## 判定

条件付き合格。Requirement承認gateはMVPとして採用する。残課題はIssue/OpenAPI生成gate、品質評価baseline、承認者/権限/再編集状態遷移である。
