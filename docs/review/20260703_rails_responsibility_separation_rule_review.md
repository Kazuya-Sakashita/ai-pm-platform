# Rails Responsibility Separation Rule Review

## 評価日時

2026-07-03 21:25 JST

## 評価担当

Codex as CTO, Tech Lead, Backend Architect, QA

## 使用フレームワーク

- G-STACK
- DDD
- ISO25010
- SPACE Framework

## Issue番号

- ISSUE-024
- GitHub Issue #24

## 良かった点

- Rails実装前にController / Modelの責務過多を確認するルールをAGENTS.mdへ追加した。
- Controller、Model、Service Object、Result Object、Query/Finder、Form、Validator、Serializer、Policy、Adapter/Gatewayの切り分け基準を明文化した。
- DI、Strategy Pattern、State Pattern、Value Object、Null Objectの検討条件を記載し、外部サービス依存をテストで差し替えやすくする方針を入れた。
- 過剰設計禁止を同じ節に入れ、短く単純な処理を無理にクラス化しない判断も残した。
- Rails実装時の報告項目を固定し、レビューで責務分離を確認できるようにした。

## 改善点

- ルール追加だけでは既存コードの責務過多を検出できない。
- Controller肥大化、Model肥大化、外部API直呼び出しをCIで検知する静的ガードは未実装。
- Serializer、Policy、Form Objectの具体例がまだ少なく、今後の実装者が判断に迷う可能性がある。
- 権限設計が本格化した時点でPolicy Objectの採用基準を再評価する必要がある。

## 優先順位

- P0: AGENTS.mdへ責務分離ルールを追加し、今後の実装報告に含める。
- P1: 代表的なService Object / Result Object / Adapterのサンプルを整理する。
- P1: Controller/Modelの肥大化を検知する軽量な静的チェックを検討する。
- P2: 認証/認可実装時にPolicy Objectの具体ルールを追加する。

## 次アクション

- ISSUE-024をGitHub Issueへ同期する。
- `AGENTS.md`、Issue台帳、レビュー文書をcommit/pushする。
- 次回以降のRails実装では、最終報告に責務分離方針、配置、過剰設計を避けた理由、テスト方針、変更ファイル一覧を含める。

## G-STACK

### Goal

Rails実装の保守性とテスト容易性を保ち、Controller / Model肥大化を未然に防ぐ。

### Strategy

AGENTS.mdに実装前チェックとして責務分離ルールを置き、以後の開発判断とレビュー報告へ組み込む。

### Tactics

- Controller / Modelの責務を限定する。
- 業務処理はService Objectへ寄せる。
- 成功/失敗/エラー理由はResult Objectで表現する。
- 外部APIはAdapter/Gatewayへ分離し、DIで差し替え可能にする。
- 過剰設計禁止を明記する。

### Assessment

ルールとしては妥当。ただし、静的チェックや既存コードレビューがない限り、運用に依存する部分が残る。

### Conclusion

AGENTS.mdへの追加は採用。次のRails実装から報告とレビューで必ず適用する。

### Knowledge

現在のRails API構成、GitHub Issue publish/reconciliation周辺のService Object、ActiveJob、Adapter/Gateway設計を前提に評価した。

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPT等の外部AIレビューは未実施。外部レビューが追加された場合は、責務分離粒度と過剰設計リスクの差分を追記する。
