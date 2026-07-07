---
name: notebooklm-workflow
description: NotebookLM向け資料整理Skill。調査資料、議事録、Issue、レビューをNotebookLMに渡しやすい構成へ整理するときに使う。
---

# NotebookLM Workflow

## Purpose

NotebookLMで参照しやすい資料セットを作る。

## When to use

- 調査資料やレビューをNotebookLMに投入する前。
- 長いdocsを質問可能な資料束へ整理するとき。
- 学習/説明用の資料を作るとき。

## Inputs

- 対象docs。
- 目的、質問したい観点。
- 除外すべきsecret/PII。

## Process

1. 目的と読者を定義する。
2. 投入資料をカテゴリ別に分ける。
3. 重複、secret、不要PIIを除く。
4. 要約、索引、主要質問を作る。
5. 出典ファイルを明記する。

## Output

- NotebookLM投入用資料リスト。
- 要約。
- 質問リスト。
- 除外理由。

## Constraints

- secretや不要PIIを含めない。
- 出典不明情報を混ぜない。
- 原文全文を必要以上にコピーしない。

## Checklist

- [ ] 目的が明確。
- [ ] 資料リストがある。
- [ ] secret/PIIを除外した。
- [ ] 質問リストがある。
