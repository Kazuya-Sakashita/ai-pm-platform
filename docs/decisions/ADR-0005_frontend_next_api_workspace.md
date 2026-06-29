# ADR-0005: FrontendはNext.js App RouterでMeeting Workspaceから実装する

## Status

Accepted

## Date

2026-06-30

## Context

ISSUE-002では、Discordログを登録し、Minutes生成、編集、承認、レビュー依頼までをユーザーが操作できる必要がある。

既存の静的プロトタイプは `prototype/` にあり、API clientはOpenAPIから `frontend/lib/api/schema.d.ts` と `frontend/lib/api/client.ts` を生成済みである。

## Decision

FrontendはNext.js App Routerで構築し、第一画面をMeeting Workspaceにする。

初期sliceでは以下に集中する。

- Project作成/選択
- Meeting保存
- Minutes生成
- Job取得
- Minutes取得/編集/承認
- Review作成

依存はroot packageへ集約し、`next dev frontend` / `next build frontend` で `frontend/` をアプリディレクトリとして扱う。

UI iconは `lucide-react` を使う。

## Dependency Security

`next@16.2.9` が内部で脆弱な `postcss@8.4.31` を引くため、`package.json` の `overrides` で `postcss@8.5.10` を固定する。

`npm audit --omit=dev` は0件である。

## Consequences

### Positive

- OpenAPI clientとUIが同じ型契約を使える。
- Meeting Workspaceを第一画面にでき、プロダクト価値をすぐ検証できる。
- root scriptsだけでbuild/devを開始でき、MVP段階の構成が単純である。

### Negative

- root packageにfrontend依存が増える。
- PlaywrightやStorybookはまだ未導入で、UI回帰検証は不足している。
- 認証/テナント境界が未実装のため、実運用前に再設計レビューが必要である。

## Alternatives Considered

- Static HTML継続: API接続と状態管理が弱く、MVP検証に足りない。
- Vite React: 軽量だが、将来のApp Router/Server Components/認証導線を考えるとNext.jsの方が拡張しやすい。
- frontend配下に独立packageを置く: 後で移行可能だが、現時点ではlockfileとscriptが分散して複雑になる。
