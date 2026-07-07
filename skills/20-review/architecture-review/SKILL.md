---
name: architecture-review
description: アーキテクチャレビュー用Skill。C4、DDD、ADR、責務分離、拡張性、技術負債、外部連携境界を評価するときに使う。
---

# Architecture Review

## Purpose

システム構成と責務境界が、AI PM Platformの成長に耐えるか評価する。

## When to use

- 新しい基盤、外部連携、Job、DB、認証、AI providerを設計するとき。
- ADRを書く前後。

## Inputs

- 要件、制約、既存ADR。
- 変更対象のコンポーネント。
- 代替案。

## Process

1. 現在の境界を整理する。
2. C4またはDDD観点で責務を確認する。
3. 代替案とトレードオフを比較する。
4. 拡張性、運用、セキュリティ、テスト容易性を確認する。
5. 後から振り返る価値があればADR化する。

## Output

- アーキテクチャレビュー。
- 採用/保留/却下の判断。
- 必要なADR。

## Constraints

- 過剰設計しない。
- 現在のMVP制約を無視しない。
- 外部サービス境界を曖昧にしない。

## Checklist

- [ ] 責務境界を説明できる。
- [ ] 代替案を比較した。
- [ ] 運用と障害時を確認した。
- [ ] ADR要否を判断した。
