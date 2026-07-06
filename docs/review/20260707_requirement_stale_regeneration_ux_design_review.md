# stale下流ドラフト再生成UX 設計レビュー

## 評価日時

2026-07-07 07:13 JST

## 評価担当

Codex / Product Manager / Tech Lead / Frontend Architect / QA / Security Engineer

## Issue番号

GitHub Issue #3: 議事録から要件定義ドラフトを生成する

## 対象

承認済みRequirementを再編集した後、既存のIssue DraftとOpenAPI Draftが `stale` になった状態の画面導線とAPIガード。

## 使用フレームワーク

- G-STACK
- HEART
- MoSCoW
- WCAG
- ISO25010

## 良かった点

- Requirement再編集時に下流Draftを `stale` 化する契約、Backend、Frontend state更新は前工程で実装済み。
- 画面上のchipで「再確認が必要」と表示され、古い成果物であることは把握できる。
- GitHub Issue公開ボタンは承認済みかつOpenAPI検証済みでなければ押せないため、主要な誤公開リスクは下がっている。
- stale化は監査ログに対象Draft IDと件数が保存され、後追い調査できる。

## 改善点

- stale状態でもIssue Draftの保存、承認、OpenAPI Draftの保存、検証が可能に見えるため、古い成果物を再利用してしまうUXリスクが残る。
- UIだけで止めるとAPI直叩きでstale Draftを更新、承認、検証できるため、Backend側の状態ガードが必要である。
- ユーザーに「Requirementを再承認して新しいDraftを生成する」という復帰条件が明示されていない。
- stale状態の説明がchipだけに依存しており、スクリーンリーダーやレビュー担当者が判断理由を見落とす可能性がある。
- 差分履歴や差分比較は未実装であり、どのRequirement変更がDraftを古くしたのかは画面上で確認できない。

## 優先順位

| 優先度 | 項目 | 判断 |
| --- | --- | --- |
| P0 | stale下流成果物の保存、承認、検証、公開をUIとAPIで抑止する | 今回対応 |
| P1 | stale理由と復帰条件を各Draftパネルに表示する | 今回対応 |
| P1 | Playwrightでstale後のボタン無効化と案内表示を確認する | 今回対応 |
| P2 | Requirement変更差分履歴を監査ログまたは専用履歴UIで表示する | 次工程 |
| P2 | 公開済みGitHub Issueへの差分反映設計を追加する | 別Issue候補 |

## G-STACK評価

| 観点 | 評価 |
| --- | --- |
| Goal | stale化した下流Draftを誤って保存、承認、検証、公開しない |
| Strategy | stale状態では編集系アクションを停止し、Requirement再承認後の再生成へ誘導する |
| Tactics | Issue/OpenAPI各パネルに再生成案内を表示し、stale時の操作ボタンとBackend APIを無効化する |
| Assessment | Request specとPlaywright happy pathでstale表示、案内、ボタン無効化、APIガードを確認する |
| Conclusion | UIの誤操作防止として実装に進んでよい |
| Knowledge | 差分履歴と公開済みIssue更新は今回のスコープ外として継続管理する |

## HEART / WCAG / ISO25010評価

- Happiness: chipだけでなく案内パネルを出すことで、ユーザーが次に何をすべきか理解しやすい。
- Engagement: stale Draftを残すことで過去成果物の存在を見失わず、再生成の判断材料にできる。
- Adoption: 生成済み成果物を突然削除しないため、既存ワークフローへの心理的抵抗が小さい。
- Retention: 誤公開を避けられるため、AI PMとしての信頼性に寄与する。
- Task Success: stale時の保存、承認、検証、公開を止めることで、古い成果物を次工程へ進める失敗を減らす。
- WCAG: 案内パネルに `aria-label` を付与し、状態理由をテキストで表現する。
- ISO25010: 使用性、信頼性、保守性の改善に該当する。

## 次アクション

1. Frontendで `issueDraft.status === "stale"` と `openApiDraft.status === "stale"` を判定する。
2. stale時はIssue Draftの保存、承認、公開をUIとAPIで無効化する。
3. stale時はOpenAPI Draftの保存、検証をUIとAPIで無効化する。
4. Issue/OpenAPI各パネルに再生成案内を表示する。
5. Request specとPlaywrightで案内表示、ボタン無効化、APIガードを確認する。

## 判定

実装に進んでよい。ただし、世界レベルSaaS基準では差分履歴、公開済みGitHub Issue更新、複数端末での再取得導線が不足しているため、Issue #3は本対応後も継続する。
