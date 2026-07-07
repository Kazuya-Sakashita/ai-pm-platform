---
name: github-pr
description: GitHub Pull Request運用Skill。PR作成、本文、CI確認、レビュー結果反映、merge、Issueクローズを行うときに使う。
---

# GitHub PR

## Purpose

PRを日本語運用、CI、レビュー、Issue同期まで含めて安全に進める。

## When to use

- PRを作成するとき。
- CIを待つとき。
- merge判断をするとき。

## Inputs

- branch名。
- Issue番号。
- 変更要約。
- 検証結果。

## Process

1. branch名を `codex/` prefixで作る。
2. 日本語コミットを作成する。
3. PR本文に概要、検証、残確認、関連Issueを書く。
4. CI required checkを待つ。
5. annotationやwarningも確認する。
6. merge後にIssueと親Issueを同期する。

## Output

- PR。
- CI証跡。
- merge結果。
- Issueコメント。

## Constraints

- CI未完了でmerge判断しない。
- Draft PRを誤ってready扱いしない。
- PR本文やコメントを不要に英語化しない。

## Checklist

- [ ] 日本語PR本文。
- [ ] 関連Issueがある。
- [ ] CIが成功。
- [ ] annotationを確認した。
- [ ] merge後にIssueを同期した。
