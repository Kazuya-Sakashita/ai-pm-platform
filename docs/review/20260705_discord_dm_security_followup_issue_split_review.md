# Discord DM security follow-up Issue分割レビュー

## 評価日時

2026-07-05 06:47:54 JST

## 評価担当

Codex as Product Owner / CTO / Tech Lead / AI Architect / Backend Architect / Frontend Architect / DevOps / Security Engineer / QA / Product Manager

## 使用フレームワーク

- G-STACK
- RICE
- MoSCoW
- STRIDE
- OWASP Top 10

## Issue番号

- ISSUE-029
- ISSUE-030
- ISSUE-031
- ISSUE-032
- ISSUE-033
- ISSUE-034

## 評価対象

ISSUE-029の初期実装後に残ったsecurity/operations/frontend quality blockerを、以下の追跡可能なIssueへ分割した。

- ISSUE-030: Discord DMインポートのproject membership/Policy Objectを設計・実装する
- ISSUE-031: DM暗号鍵rotation/KMS/backup削除方針ADRを作成する
- ISSUE-032: Conversation Summary Draft JSON本文の保護方針を実装する
- ISSUE-033: retention worker staging/production smoke runbookを実施可能にする
- ISSUE-034: Discord DM Frontendの匿名化失敗・キャンセル・権限エラーE2Eを追加する

GitHub同期コメント: `https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/29#issuecomment-4883908857`

## 良かった点

- ISSUE-029を巨大な残課題のままにせず、権限、鍵管理、派生データ保護、worker運用、Frontend失敗系へ分割した。
- GitHub App live credentialが不要な作業を明確に切り出したため、ブロックされずに前進できる。
- DM原文だけでなくAI整理draftを派生センシティブデータとして扱い、世界レベルSaaS基準に近づけた。
- retention jobを実装だけで終わらせず、staging/production worker smoke対象へ昇格した。
- GitHub Issue #30〜#34 とローカル `docs/issue/` の両方へ同期した。

## 改善点

- 現時点では分割Issueの作成までであり、#30〜#34の実装/ADR/runbookは未完了。
- ISSUE-030は認証/認可基盤全体と絡むため、実装前に既存のUser/Project/member model方針を再確認する必要がある。
- ISSUE-031はクラウドKMSの実環境が未確定であり、ADRだけでproduction-readyとは言えない。
- ISSUE-033はstaging/production環境がない限り、実行証跡までは保存できない。
- ISSUE-034はP1にしたが、削除/匿名化操作の誤操作リスクを考えると早めに消化すべきである。

## 優先順位

| Priority | Issue | 理由 |
| --- | --- | --- |
| P0 | ISSUE-030 | Broken Access ControlはDM漏えいに直結する |
| P0 | ISSUE-031 | 鍵管理とbackup削除方針がない暗号化は監査に弱い |
| P0 | ISSUE-032 | AI整理draftが派生センシティブデータとして残る |
| P0 | ISSUE-033 | retention jobはworkerで実行されなければ削除SLOを満たせない |
| P1 | ISSUE-034 | UX回帰防止として重要だが、権限/鍵/派生データ保護より優先度は一段下 |

## 次アクション

1. ISSUE-031でADRとsecurity checklistを先に作る。
2. ISSUE-033で既存worker smoke runbookへretention job手順を追記する。
3. ISSUE-034でFrontend failure path E2Eを追加する。
4. ISSUE-030は認証/認可モデル確認後にAPI設計レビューから開始する。
5. ISSUE-032はschema/暗号化互換性を確認してから設計レビューへ進む。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DM由来データのproduction blockerを追跡可能な単位へ分解する |
| Strategy | セキュリティ、運用、Frontend品質を独立Issueに分割し、GitHub App依存を避けて進める |
| Tactics | #30〜#34のGitHub Issue作成、ローカルIssue台帳同期、#29への分割結果追記 |
| Assessment | 分割は妥当。ただしIssue作成だけではリスクは下がらず、次の実装/ADR/runbookが必要 |
| Conclusion | 次はISSUE-031またはISSUE-033から進めるのが最短で実効リスクを下げる |
| Knowledge | AI PM Platformでは原文、派生AI出力、job運用、権限が一体でデータ保護品質を決める |

## STRIDE / OWASP観点

| 観点 | 残リスク | 対応Issue |
| --- | --- | --- |
| Spoofing | actorが実ユーザーと紐付いていない | ISSUE-030 |
| Tampering | 権限なしの更新/承認/匿名化を防ぐPolicyがない | ISSUE-030 |
| Repudiation | 誰が削除/承認したかの監査粒度が弱い | ISSUE-030 |
| Information Disclosure | 鍵管理、backup、summary draft JSONが未成熟 | ISSUE-031, ISSUE-032 |
| Denial of Service | retention worker未実行で削除期限を満たせない | ISSUE-033 |
| Elevation of Privilege | project membership未実装 | ISSUE-030 |

## 判定

条件付き合格。Issue分割は適切だが、世界レベルSaaS基準ではまだ実装完了ではない。次工程ではISSUE-031、ISSUE-033、ISSUE-034をGitHub App不要で先に消化し、ISSUE-030/032は設計レビューを挟んで進める。

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPTなど外部AIレビューは未実施。外部レビュー結果が追加された場合は、権限境界、KMS/backup方針、派生AI出力の扱いに差分がないか比較する。
