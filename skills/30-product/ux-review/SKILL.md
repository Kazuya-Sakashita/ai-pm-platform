---
name: ux-review
description: UXレビュー用Skill。導線、アクセシビリティ、状態表示、エラー復旧、モバイル幅、UI一貫性を確認するときに使う。
---

# UX Review

## Purpose

AI PM PlatformのUIが、実作業で迷わず使えるか確認する。

## When to use

- Frontend実装後。
- 新しい操作導線や復旧導線を追加したとき。
- E2Eやスクリーンリーダー確認の前。

## Inputs

- 対象画面。
- ユーザーフロー。
- 状態、エラー、空データ。
- Playwright結果。

## Process

1. 主要タスクを1つずつ辿る。
2. loading、empty、error、successを確認する。
3. ボタン、select、checkboxなど標準UIを使っているか見る。
4. 狭幅、長文、overflowを確認する。
5. aria label、keyboard操作、視認性を確認する。

## Output

- UX指摘。
- 改善案。
- 必要なE2E追加案。

## Constraints

- 操作説明文を画面に増やしすぎない。
- テキストのはみ出しを放置しない。
- UIカードの過剰ネストを避ける。

## Checklist

- [ ] 主要導線が自然。
- [ ] 状態表示がある。
- [ ] エラー復旧できる。
- [ ] モバイル幅で破綻しない。
- [ ] a11yを確認した。
