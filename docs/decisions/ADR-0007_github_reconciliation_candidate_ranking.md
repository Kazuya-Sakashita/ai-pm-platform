# ADR-0007: GitHub reconciliation候補のscore、並び順、最大表示件数方針

## Status

Accepted

## Date

2026-07-02

## Context

GitHub Issue publish reconciliationでは、AI PM markerをGitHub Issue本文から検索し、1件だけ見つかった場合は自動でローカルIssue Draftへ紐付ける。0件または複数件の場合は、二重Issue作成や誤リンクを避けるため人間レビューに止める。

現在は複数候補のUIに `title`、`state`、`updated_at`、`score` を表示できるようになった。一方で、GitHub Search APIの `score` は検索 relevance の参考値であり、AI PM Platformの業務的な正しさや安全性を保証するものではない。

世界レベルのSaaSとしては、候補を便利に提示しながら、誤ったIssueへ自動リンクしない統制が必要である。

## Decision

MVPでは以下の方針を採用する。

1. GitHub Search APIのdefault best match順を候補表示順として保持する。
2. `github_issue_score` は補助情報として表示するが、自動選択や自動紐付けの根拠にしない。
3. marker検索は最大10件を取得・表示する。
4. 1件だけ見つかった場合のみ自動reconcileを許可する。
5. 0件または複数件では、自動判定せずReview blockerと人間選択に止める。
6. closed Issueも候補から除外しない。状態を表示し、人間が判断できるようにする。
7. 候補レスポンスには安全な判断材料だけを含め、GitHub raw response全文は返さない。

## Candidate Ordering

表示順はGitHub Search APIの応答順を維持する。

理由:

- GitHubのsearch rankingはquery、repository、本文一致、更新状況などを総合したbest matchであり、MVPでは独自rankingより安定している。
- scoreの数値だけでsortすると、GitHub側のranking意図や将来仕様変更を壊す可能性がある。
- AI PM markerは完全一致検索に近いため、複数候補が出る時点で異常系または重複作成疑いであり、rankingより監査判断が重要である。

## Score Policy

`github_issue_score` は以下として扱う。

- 画面表示: 参考情報として表示する。
- 自動判断: 使用しない。
- 監査: Review blockerやコメントで必要に応じて参照できる。
- API contract: nullable/optionalな数値として扱う。

scoreが高い候補であっても、複数候補の場合は自動linkしない。

## Max Display Count

MVPの上限は10件とする。

理由:

- 人間レビューで一度に比較できる上限として妥当。
- 現行 `MarkerSearchClient` は `per_page=10` で検索しており、API/Frontendの挙動と一致する。
- 10件を超える場合は、候補選択以前にmarker重複または検索設計の異常として扱うべきである。

将来的には `total_count` と `incomplete_results` をAPIレスポンスへ追加し、10件超過やGitHub searchの不完全結果を明示する。

## State Policy

closed Issueは候補から除外しない。

理由:

- GitHub Issue作成後に人間が手動closeした場合でも、ローカル台帳としては正しい紐付け先である可能性がある。
- closedを除外すると、実際には作成済みのIssueを見落として二重作成を誘発する。
- closedであることは選択リスクとしてUIに表示すればよい。

## Security and Privacy

候補APIで返してよい情報:

- Issue number
- Issue URL
- Repository
- Title
- State
- Updated at
- Search score
- GitHub issue API id
- GitHub node id

返さない情報:

- GitHub raw response全文
- installation access token
- Authorization header
- Idempotency-Key生値
- Issue本文全文
- コメント本文
- user/account raw payload

## UX Requirements

候補UIは以下を満たす。

- 候補番号、title、state、updated_at、score、URLを比較できる。
- 選択済み候補が視覚的に分かる。
- 選択済み候補は `aria-pressed` または同等のアクセシビリティ属性で分かる。
- 長いtitle/URLでレイアウトが崩れない。
- scoreだけで正解が決まるような文言にしない。

## Consequences

### Positive

- GitHub検索結果を便利に見せながら、誤リンクの自動化を避けられる。
- scoreの意味を過大評価しないため、安全側の運用になる。
- closed Issueも見えるため、二重Issue作成リスクを下げられる。
- 10件上限により、人間レビューの負荷を抑えられる。

### Negative

- 複数候補時の自動復旧率は上がらない。
- 10件超過やincomplete searchを明示するにはAPI拡張が必要。
- 選択済み状態、long title、狭幅表示のUI検証が追加で必要。
- GitHub Search APIのranking仕様変更には影響を受ける。

## Alternatives Considered

### Highest score候補を自動linkする

不採用。

理由:

- scoreは業務的な正しさの保証ではない。
- 誤リンクした場合、監査台帳とGitHubの対応関係が壊れる。
- 複数候補は異常系として人間レビューに止めるべきである。

### closed Issueを候補から除外する

不採用。

理由:

- 手動close済みの正しいIssueを見落とす。
- 見落としによりcontrolled retryで二重作成する危険がある。

### 全候補を無制限に表示する

不採用。

理由:

- 人間レビューの認知負荷が高い。
- 10件を超える場合は候補選択ではなく検索/marker運用の異常として扱う方が安全。

### 独自AI rankingを導入する

不採用。

理由:

- MVPでは説明可能性と監査性を優先する。
- AI rankingは便利だが、誤判断時の責任境界が曖昧になる。
- 現時点ではmarker完全一致と人間レビューで十分である。

## Implementation Follow-up

- [Done 2026-07-02] 候補APIに `title`、`state`、`updated_at`、`score` を追加する。
- [Done 2026-07-02] Frontendで候補メタデータを表示する。
- [Todo] 候補選択済み状態とアクセシビリティ属性を追加する。
- [Todo] 長いtitle/URLの視覚回帰E2Eを追加する。
- [Todo] `total_count`、`incomplete_results`、10件超過表示のAPI拡張要否を検討する。
- [Todo] live GitHub App credentialでcandidate metadata smokeを実施する。
