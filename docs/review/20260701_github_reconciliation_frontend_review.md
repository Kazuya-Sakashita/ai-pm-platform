# GitHub Reconciliation Frontend Review

## 評価日時

2026-07-01 19:05:33 JST

## 評価担当

- Codex
- Product Manager
- Tech Lead
- Frontend Architect
- Security Engineer
- QA

## 使用フレームワーク

- G-STACK
- HEART
- WCAG
- ISO25010
- STRIDE

## 対象

- Issue番号: #4
- 対象ファイル:
  - `frontend/app/workspace-client.tsx`
  - `frontend/app/globals.css`
  - `frontend/e2e/meeting-workspace.spec.ts`

## 良かった点

- Publish失敗時に、marker検索、既存GitHub Issue手動リンク、controlled retry承認を同じIssue Draft画面から実行できるようにした。
- `reconcile-github-publish` と `resolve-github-reconciliation` をOpenAPI生成型経由で呼び出し、FrontendとAPI contractの乖離を避けた。
- 手動リンクではIssue番号、Issue URL、resolution noteを入力させ、監査ログに必要な判断根拠をUIから渡せるようにした。
- controlled retryでもresolution noteを必須にし、安易な再publishを避ける運用導線にした。
- 成功/失敗後にIssue Draftを再取得し、公開済みURLまたは失敗状態を画面に反映するようにした。
- Playwright E2Eで公開失敗時の復旧UI表示を検証し、既存の会議からIssue/OpenAPI/Publishまでの本流に組み込んだ。
- CSSは既存の管理画面トーンを維持し、900px未満で1列化するレスポンシブ制約を追加した。

## 改善点

- 実GitHub App credentialが未設定のため、connect、publish、reconcile、manual link、controlled retryのlive smokeは未実施。
- marker検索結果が0件/複数件だった場合の候補Issue一覧表示がなく、レビュアーはGitHub側で別途確認する必要がある。
- `publish_failed` であれば復旧UIを表示するため、GitHub未接続などreconciliation attemptがない失敗でも操作可能に見える。
- resolution noteの入力は必須だが、最小文字数、テンプレート、承認者表示、再試行回数制限は未実装。
- GitHub searchのindexing delay、rate limit、retry/backoff状態をFrontendで可視化できていない。
- キーボード操作とスクリーンリーダー向けのエラー要約、成功時フォーカス移動はまだ最低限。
- 実運用ではreconciliation操作の権限分離が必要だが、現在は認証/認可がMVP外で未接続。

## 優先順位

- P0: 実GitHub App credentialで connect + publish + reconcile + manual resolve のlive smokeを実施する。
- P0: reconciliation attemptが存在する場合のみ復旧操作を強く表示できるよう、APIまたはIssue Draft responseにpending attempt情報を追加する。
- P1: marker検索結果をFrontendで候補一覧として表示し、正しいIssueを選択して手動リンクできるようにする。
- P1: controlled retryにcooldown、retry count、承認者、理由テンプレートを追加する。
- P1: GitHub search rate limit/indexing delayをJob detailまたはUI statusへ出す。
- P2: WCAG観点でエラー要約、フォーカス管理、補助テキストを改善する。

## 次アクション

- GitHub App credentialを設定し、実GitHub repositoryでconnect/publish/reconcile smokeを行う。
- Issue Draft responseへpending reconciliation attempt summaryを追加するAPI設計をIssue化またはIssue #4残タスクとして進める。
- marker検索候補一覧と手動選択UIのOpenAPI設計を作成する。
- retry/backoff/cooldown方針をADR化する。
- Frontend E2Eにmanual linkとcontrolled retryのmock/APIテストを追加する。

## Issue番号

- #4

## レビュー結果

Issue #4のFrontend工程としては合格。ただし世界レベルのSaaS基準では、実credential smoke、候補Issue選択、権限分離、retry制御がないため完了ではない。次はlive GitHub App検証、またはpending attempt情報をAPI responseへ出してUIの誤操作余地を下げる改善を優先する。

## 検証結果

- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
