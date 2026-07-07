---
name: nextjs-frontend
description: Next.js Frontend実装用Skill。React UI、状態管理、OpenAPI生成型、API呼び出し、Playwright、アクセシビリティ、日本語表示を整理するときに使う。
---

# Next.js Frontend

## Purpose

Next.js UIを、OpenAPI契約に沿って一貫したUXで実装する。

## When to use

- Frontend UI、状態、API呼び出し、E2Eを変更するとき。
- 表示文言、エラー導線、再接続導線を追加するとき。
- レスポンシブやアクセシビリティを確認するとき。

## Inputs

- OpenAPI生成型。
- 既存UI構造とCSS。
- Playwright対象シナリオ。

## Process

1. OpenAPI生成型を使う。
2. API呼び出し、状態更新、表示を分離して読む。
3. UI文言は日本語で統一する。
4. ボタン、select、checkbox、tabsなど適切な標準UIを使う。
5. 狭幅viewport、長文、エラー表示を確認する。
6. Playwrightで主要導線を検証する。

## Output

- 型安全なAPI呼び出し。
- 一貫したUI。
- Playwright検証。

## Constraints

- OpenAPI生成型を手書きで崩さない。
- UIカードを過剰にネストしない。
- 表示文言に不要な英語を混ぜない。
- text overflowを放置しない。

## Checklist

- [ ] 生成型に沿っている。
- [ ] loading/error/empty状態がある。
- [ ] 日本語表示チェックを通した。
- [ ] buildが通る。
- [ ] 必要なE2Eがある。
