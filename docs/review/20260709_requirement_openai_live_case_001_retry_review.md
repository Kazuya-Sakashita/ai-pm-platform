# Requirement OpenAI live CASE-RQ-001 再実行レビュー

## 評価日時

2026-07-09 04:51:14 JST

## 評価担当

- Codex
- AI Architect
- Security Engineer
- QA
- Product Manager

## Issue番号

- ISSUE-052
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/69

## 対象

- `npm run requirements:openai:readiness`
- `scripts/evaluate-requirement-generation.rb`
- `docs/evaluation/20260709_requirement_generation_openai_live_case_001_failure.md`
- `docs/evaluation/20260709_requirement_generation_openai_live_case_001_resume.json`
- `docs/release/20260708_requirement_openai_quota_operator_checklist.md`

## 使用フレームワーク

- G-STACK
- STRIDE
- ISO25010
- RICE

## 実施内容

`.env` 読込条件でOpenAI live評価readinessを再確認し、`safe_failures` が空であることを確認した。その後、`CASE-RQ-001` のみを `--delay-seconds 10`、`--failure-output`、`--resume-output` 付きで低負荷再実行した。

結果は `insufficient_quota` / `too_many_requests` によるsafe failureであり、OpenAI出力品質は基準未判定のままである。

## 良かった点

- API keyとmodelの設定確認は、secret値を出さずに完了した。
- live評価失敗時もstack traceではなくsafe failure reportとresume JSONを保存できた。
- request idの存在だけを記録し、raw provider responseやrequest payload全文を保存しなかった。
- `CASE-RQ-001` から再開できる状態を維持した。
- CIへ外部API依存を持ち込まず、manual smokeとして隔離できている。

## 改善点

- `insufficient_quota` が再発しており、OpenAI Platform側のbilling、usage、budget、project紐付け、model accessのどこに原因があるかは未確定である。
- readinessは設定有無を確認できるが、実quotaやbilling状態までは検証できない。
- OpenAI出力品質が未判定のため、deterministic providerとの差分評価へ進めない。
- safe failure report上のFixture issueは `ISSUE-003` であり、運用Issue `ISSUE-052` との対応はreview doc側で補足する必要がある。

## 改善案

- OpenAI Platformで対象projectのbilling有効化、monthly budget、hard limit、usage、rate limitを確認する。
- API keyの所属project / organizationが、billing確認対象と一致しているか確認する。
- `OPENAI_REQUIREMENT_MODEL` が対象projectで利用可能なResponses API対応modelであることを確認する。
- quotaが回復した後も、最初は `CASE-RQ-001` のみ、`--delay-seconds 10` 付きで再実行する。
- 成功時は評価Markdown、P0未達件数、Critical failure件数、deterministic providerとの差分を必ず保存する。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | secret、raw response、payload全文、model outputを保存しない | 情報漏えい防止の必須条件 |
| P1 | OpenAI Platform側のquota / billing / project紐付けを確認する | live評価が先へ進まない直接ブロッカー |
| P1 | `CASE-RQ-001` から低負荷再実行する | 評価条件を固定し、比較可能性を保つため |
| P2 | 成功後にdeterministic providerとの差分評価を保存する | Issue #69の完了条件 |

## G-STACK

### Goal

Requirement生成のOpenAI providerが、実AI出力でもP0基準を満たすか確認する。

### Strategy

CIから分離したmanual smokeとして、1ケースずつ低負荷で実行し、成功時も失敗時も安全な証跡だけを残す。

### Tactics

- `.env` 読込条件でreadinessを確認する。
- `CASE-RQ-001` のみを実行する。
- 失敗時はsafe failure reportとresume JSONを保存する。
- API key、Authorization header、raw response、payload全文、model outputを保存しない。

### Assessment

readinessは合格しているが、live評価はOpenAI Platform側のquota制約で停止している。アプリ側safe failure処理は期待どおり機能している。

### Conclusion

Issue #69はOPEN継続。次工程はOpenAI Platform側のbilling、usage、limits、model access、API key所属project確認である。

### Knowledge

2026-07-09時点で `CASE-RQ-001` は `insufficient_quota` / `too_many_requests` により未評価である。

## STRIDE観点

| 観点 | リスク | 対応 |
| --- | --- | --- |
| Spoofing | 別projectのAPI keyで評価してしまう | API key所属project / organizationをPlatform側で確認する |
| Tampering | 評価条件が再実行ごとに変わる | `CASE-RQ-001` とfixture versionを固定する |
| Repudiation | 失敗理由が曖昧になる | safe failure reportとresume JSONを保存する |
| Information Disclosure | API keyやraw responseがdocsへ混入する | 保存禁止情報を明示し、secret pattern scanを実施する |
| Denial of Service | quota不足の連続再試行でさらに制限される | `--delay-seconds 10` と単一caseで低負荷にする |
| Elevation of Privilege | 外部API結果をレビューなしで完了扱いにする | review doc保存とIssue #69 OPEN継続を維持する |

## ISO25010観点

- 保守性: safe failureとresumeにより、次回再実行位置が明確である。
- 信頼性: quota不足でもプロセスが壊れず、基準未判定として停止できている。
- セキュリティ: secret、raw response、payload全文、model outputを保存していない。
- 使用性: operator checklistに沿って次アクションを判断できる。
- 互換性: 通常CIはdeterministic providerのまま維持されている。

## RICE

| 項目 | 評価 |
| --- | --- |
| Reach | Requirement生成を使う全ワークフローに影響 |
| Impact | AI生成品質の上限確認に直結するため高い |
| Confidence | アプリ側safe failureの信頼度は高いが、OpenAI出力品質は未判定 |
| Effort | Platform設定確認後の再実行は低い |

## 次アクション

1. OpenAI Platform側でbilling、usage、limits、model access、API key所属projectを確認する。
2. quota制約が解消した後、`CASE-RQ-001` を低負荷再実行する。
3. 成功時は評価Markdownとdeterministic providerとの差分評価を保存する。
4. 失敗時はsafe failure reportとresume JSONを更新し、Issue #69へ同期する。

## 検証結果

- `npm run requirements:openai:readiness`: `safe_failures` 空
- OpenAI live `CASE-RQ-001`: `insufficient_quota` / `too_many_requests` でsafe failure
- safe failure report: `docs/evaluation/20260709_requirement_generation_openai_live_case_001_failure.md`
- safe resume JSON: `docs/evaluation/20260709_requirement_generation_openai_live_case_001_resume.json`
- 保存していない情報: API key、Authorization header、raw provider response、request payload全文、model output、PII / credential / token

## 結論

アプリ側の安全な失敗処理は合格。ただしOpenAI出力品質は未判定であり、Issue #69をクローズしてはならない。次はOpenAI Platform側のquota / billing / project紐付け確認が必要である。
