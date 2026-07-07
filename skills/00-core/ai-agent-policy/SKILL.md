---
name: ai-agent-policy
description: AI provider、Codex、専門家サブエージェント、外部AIレビュー、prompt、MCP、agent設計を扱うときのSkill。AI出力、レビュー比較、安全性、秘密情報保護を確認したいときに使う。
---

# AI Agent Policy

## Purpose

AI Agent活用を、監査可能で安全なプロジェクト価値に接続する。

## When to use

- OpenAI provider、prompt、Structured Outputsを扱うとき。
- 専門家サブエージェントや外部AIレビューを設計するとき。
- AI出力をIssue、要件、レビューへ接続するとき。

## Inputs

- 対象AI機能の目的。
- 入出力schema、prompt、評価fixture。
- 秘密情報、PII、監査ログの扱い。

## Process

1. AI利用目的をプロダクト価値に結びつける。
2. deterministic fallbackとCI非依存方針を確認する。
3. JSON schema、validation、safe errorを定義する。
4. PII、secret、raw prompt、raw chain-of-thoughtを保存しない。
5. 必要に応じて専門家ロール分離レビューを行う。
6. 外部AIレビューは利用可否と差分分析を記録する。

## Output

- AI設計方針。
- 評価結果。
- 安全な失敗contract。
- レビュー文書。

## Constraints

- raw chain-of-thoughtを保存しない。
- secret、token、不要PIIを保存しない。
- 外部AIに送る情報は最小化する。
- Security EngineerとQAのP0 blockerを無視しない。

## Checklist

- [ ] AI利用目的が明確。
- [ ] schema検証がある。
- [ ] deterministic fallbackがある。
- [ ] safe errorがある。
- [ ] 評価fixtureまたはレビューがある。
