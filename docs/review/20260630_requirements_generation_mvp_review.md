# 2026-06-30 Requirements Generation MVP レビュー

## 評価日時

2026-06-30 16:40 JST

## 評価担当

Codex as Product Manager / Tech Lead / Backend Architect / Frontend Architect / QA / AI Architect / Security Engineer

外部AIレビュー: 未実施。Claude / ChatGPT 等の別AIレビューは追加待ち。

## 使用フレームワーク

- G-STACK
- MoSCoW
- ISO25010
- WCAG
- DDD
- STRIDE

## 良かった点

- Issue #3の中核である「承認済みMinutesからRequirement draftを生成する」縦切りを実装した。
- `requirements` テーブル、Model、Service、Controller、OpenAPI、TypeScript型、Frontend編集UI、Playwright E2Eまで接続した。
- Minutesが `approved` になるまでRequirement生成を409 `review_required` で止め、AGENTSのレビューゲート思想をプロダクト動作にも反映した。
- 生成結果は背景、目的、ユーザーストーリー、機能要件、非機能要件、受け入れ条件、非スコープ、未決事項、リスクに分解して保存できる。
- Requirement review依頼をFrontendから作成でき、Issue生成前のレビュー導線を作った。

## 改善点

- Requirement生成はdeterministic providerであり、実AI品質評価やOpenAI providerは未実装。
- 生成品質の評価セット、golden dataset、回帰評価がないため、世界レベルSaaS基準ではAI出力品質の保証が弱い。
- Requirement承認APIがなく、Issue/OpenAPI生成へ進む前の状態遷移が未完成。
- FrontendはMeeting Workspace内にRequirement Workspaceを追加しただけで、情報量が増えた時の分割ビューや比較UXは不足している。
- E2E test data cleanupが未整備で、ローカルDBにテストデータが蓄積する。

## 優先順位

1. P0: Requirement承認APIとReview gateを追加する
2. P0: Requirement生成品質の評価セットを作る
3. P0: Issue #4に進む前にRequirement approved状態をIssue/OpenAPI生成条件へ接続する
4. P1: OpenAI providerによるRequirement生成と失敗契約テストを追加する
5. P1: Requirement Workspaceの情報設計を分割し、差分、未決事項、リスクを強調する

## 次アクション

- GitHubへpushし、CIでRSpec、OpenAPI verify、Frontend build、Playwright E2Eが通ることを確認する。
- Issue #3はMVP縦切りとして大きく前進したが、承認APIと品質評価が未完了のためopen継続。

## Issue番号

- GitHub Issue: #3

## G-STACK

### Goal

議事録から、Issue生成とOpenAPI設計の入力に使える要件定義ドラフトを生成、編集、レビュー依頼できるようにする。

### Strategy

まず外部AIに依存しないdeterministic providerで、DB/API/Frontend/Review gateの縦切りを安定させる。

### Tactics

- Requirement modelとmigrationを追加
- `RequirementGenerationService` とdeterministic providerを追加
- `/minutes/{minutes_id}/generate-requirement`、`/requirements/{requirement_id}` を実装
- FrontendにRequirement Workspaceと編集/保存/レビュー依頼導線を追加
- Playwright E2EでMinutes承認後のRequirement生成を確認

### Assessment

プロダクト価値の中核である「議事録から要件定義」へ進めた点は大きい。一方、AI品質評価、承認、Issue生成条件との接続が未完成であり、完成扱いにはできない。

### Conclusion

条件付き合格。Issue #3のMVP縦切りとして採用するが、次工程へ進む前にRequirement承認と品質評価の強化が必要。

### Knowledge

レビューゲートは文書ルールだけでなく、APIの状態遷移として表現しないとプロダクト上で守られない。

## MoSCoW

| 区分 | 内容 | 状態 |
| --- | --- | --- |
| Must | 承認済みMinutesからRequirement draft生成 | 完了 |
| Must | 背景、目的、受け入れ条件、未決事項の保存 | 完了 |
| Must | 人間編集UI | 完了 |
| Must | Requirementレビュー保存 | 完了 |
| Should | Requirement承認API | 未完了 |
| Should | AI生成品質評価セット | 未完了 |
| Could | OpenAI providerによる高度生成 | 未完了 |
| Won't now | 完全自動承認 | 非スコープ |

## STRIDE

| 脅威 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | 認証/actorは未実装 | Issue #6で対応 |
| Tampering | Requirement編集は可能だが変更差分履歴はない | AuditLogは保存、versioningは未実装 |
| Repudiation | generation/updateはAuditLogに残る | actor_id強化が必要 |
| Information Disclosure | Minutes由来データをRequirementへ展開 | #2のsecret scanが前段にあるがRequirement側独自scanは未実装 |
| Denial of Service | 生成は同期処理 | background job化は未実装 |
| Elevation of Privilege | Requirement生成/編集に権限境界なし | Issue #6で対応 |

## 検証結果

- `bundle exec rspec`: 33 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功。OpenAPI contract warningなし。Node version warningのみ既知
- `npm run frontend:build`: 成功
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

## 判定

条件付き合格。Requirement生成MVPとして採用するが、Issue #3は承認API、AI品質評価、OpenAI provider拡張が残るためopen継続。
