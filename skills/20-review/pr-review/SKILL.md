---
name: pr-review
description: Pull Requestレビュー用Skill。PR本文、CI、差分、Issue紐付け、レビュー文書、マージ可否を確認するときに使う。
---

# PR Review

## Purpose

PRがIssue、レビュー、CI、ドキュメント、品質条件を満たしているか確認する。

## When to use

- PR作成前。
- PR CI確認後。
- merge判断前。

## Inputs

- PR URL。
- Issue番号。
- 差分、CI、レビュー文書。

## Process

1. PRタイトルと本文が日本語運用に合うか確認する。
2. Issue番号、関連docs、検証結果を確認する。
3. CI required checkを確認する。
4. 差分に不要な生成物や無関係変更がないか確認する。
5. 未完了リスクをPR本文またはIssueへ残す。

## Output

- PRレビュー結果。
- merge可否。
- Issueコメントまたはレビュー文書。

## Constraints

- CIが未完了なら完了扱いしない。
- Draft PRを誤ってmergeしない。
- 英語PR本文を放置しない。

## Checklist

- [ ] PR本文が日本語。
- [ ] Issueと紐づく。
- [ ] CIが成功。
- [ ] docs/reviewがある。
- [ ] 残リスクを記録した。
