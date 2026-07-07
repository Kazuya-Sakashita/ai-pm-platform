---
name: github-issue
description: GitHub Issue運用Skill。docs/issue台帳、GitHub Issue作成、同期、コメント、クローズ判断、親子Issue管理を行うときに使う。
---

# GitHub Issue

## Purpose

ローカルIssue台帳とGitHub Issueを同期し、Issue駆動開発を保つ。

## When to use

- 新しい作業をIssue化するとき。
- 完了済みIssueをクローズするとき。
- 親Issueへ進捗を同期するとき。

## Inputs

- `docs/issue/` のIssue台帳。
- GitHub Issue URL。
- 完了条件と検証結果。

## Process

1. まず `docs/issue/` にIssueを作る。
2. GitHub Issueへ同じ内容を登録する。
3. URLをローカル台帳へ反映する。
4. 作業後に検証結果をIssueへコメントする。
5. 完了条件を満たしたらクローズする。
6. 親Issueがあれば進捗を同期する。

## Output

- ローカルIssue台帳。
- GitHub Issue。
- 進捗コメント。
- クローズ判断。

## Constraints

- Issueなしで実装しない。
- GitHubに同期できない場合は理由を台帳へ書く。
- 日本語でIssue本文とコメントを書く。

## Checklist

- [ ] ローカル台帳がある。
- [ ] GitHub URLがある。
- [ ] 完了条件がある。
- [ ] 検証結果をコメントした。
- [ ] クローズ可否を判断した。
