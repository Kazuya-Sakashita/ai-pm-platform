# 2026-06-30 Toolchain version policy

## 対象Issue

- ISSUE-019: Node/toolchain versionを固定する

## 目的

ローカル開発、CI、Codex実行環境でtoolingの挙動を揃える。

## Node.js

採用:

- Node.js `22.12.0`
- npm `10.x`

理由:

- Redocly CLIがNode `>=22.12.0` または `>=20.19.0 <21.0.0` を要求するため。
- Next.js frontend実装でも新しめのNode LTS系に寄せやすい。

設定:

- `.node-version`
- `package.json` engines

## Ruby/Rails

Backend scaffold時に以下を前提候補とする。

- Ruby `3.3.x` or newer stable
- Rails API latest stable at scaffold time

Rails/Rubyの正確なversionは、Backend scaffold時にGemfileと`.ruby-version`で固定する。

## PostgreSQL

MVP候補:

- PostgreSQL `16` or `17`

Docker compose作成時にimage tagを固定する。

## Browser testing

Playwrightはfrontend workspaceに依存として固定する。

今回の静的プロトタイプQAでは、`npx playwright screenshot` を利用してChromium screenshotを取得した。

## CI方針

CIでは以下を明示する。

- Node.js `.node-version` と同一
- npm ci
- Ruby version from `.ruby-version`
- PostgreSQL image tag fixed
- `npm run api:verify`

## 現在の注意

現時点のローカルNodeは `v22.7.0` であり、Redocly CLIはengine warningを出す。`api:verify` は成功するが、CI導入前にNode `22.12.0` へ揃える。

