---
name: code-review
description: コードレビュー用Skill。バグ、回帰、責務分離、テスト不足、保守性、セキュリティ影響を優先してレビューするときに使う。
---

# Code Review

## Purpose

実装差分を世界レベルSaaS基準で評価し、重大リスクを先に見つける。

## When to use

- PR前、PRレビュー、実装完了レビュー。
- Backend、Frontend、OpenAPI、テスト差分を確認するとき。

## Inputs

- 差分、Issue、OpenAPI、テスト結果。
- 関連レビューとADR。

## Process

1. Findingsを重大度順に出す。
2. バグ、回帰、権限、データ漏洩、テスト不足を優先する。
3. ファイル/行番号を根拠にする。
4. 仕様不明点はOpen questionにする。
5. 改善案を必ず書く。

## Output

- Findings。
- Open questions。
- 改善案。
- 必要ならレビュー文書。

## Constraints

- 良かった点だけで終わらない。
- 好みの指摘を重大バグより優先しない。
- 根拠のない断定をしない。

## Checklist

- [ ] 重大度順に確認した。
- [ ] セキュリティと権限を確認した。
- [ ] テスト不足を確認した。
- [ ] 改善案を書いた。
