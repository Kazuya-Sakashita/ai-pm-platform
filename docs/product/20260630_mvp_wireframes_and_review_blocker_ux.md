# 2026-06-30 MVPワイヤーフレームとReview blocker UX

## 対象Issue

- ISSUE-007: MVPワイヤーフレームとReview blocker UXを詳細化する

## 目的

MVP実装前に、主要画面のレイアウト、レビューゲート、生成失敗、再試行、部分再生成、レスポンシブ方針を具体化する。

この資料はFigmaの代替ではなく、実装チームが迷わず画面構造と状態を起こせるための設計仕様である。

## 対象画面

- Project Workspace
- Meeting Workspace
- Requirement Workspace
- Review Center
- Issue Draft Workspace
- OpenAPI Draft Workspace

## 共通レイアウト

MVPはデスクトップ優先で設計する。最小実用幅は `1280px`、推奨幅は `1440px` 以上とする。

```text
+--------------------------------------------------------------------------------+
| Top Bar: Project selector | GitHub status | Review gate status | Account        |
+-------------------+------------------------------------------------------------+
| Sidebar           | Page header                                                |
|                   |------------------------------------------------------------|
| Projects          | Context bar: current artifact, status, primary action      |
| Meetings          |------------------------------------------------------------|
| Requirements      | Main work area                                             |
| Issues            |                                                            |
| OpenAPI           |                                                            |
| Reviews           |                                                            |
| Integrations      |                                                            |
| Audit Log         |                                                            |
+-------------------+------------------------------------------------------------+
```

### 固定領域

- Sidebar width: 240px
- Top bar height: 56px
- Context bar height: 56px
- Right inspector width: 320pxから380px
- Main content min width: 720px

### 共通コンポーネント

- Status chip: draft, generating, in_review, needs_changes, approved, failed
- Review gate badge: Clear, Action required, Review missing, Accepted risk
- Primary action button: 画面ごとに1つだけ
- Secondary actions: icon button or menu
- Inspector panel: review, decisions, risks, audit summary
- Inline alert: validation, secret detection, integration error

## Project Workspace

### 目的

プロジェクト全体の現在地を示し、次に進める作業を明確にする。

### ワイヤーフレーム

```text
+--------------------------------------------------------------------------------+
| Top Bar                                                                        |
+-------------------+------------------------------------------------------------+
| Sidebar           | Project: AI PM Platform                     [Add Meeting]  |
|                   | GitHub: Not connected   Review gate: 3 blockers           |
|                   |------------------------------------------------------------|
|                   | Pipeline                                                   |
|                   | +----------+  +----------+  +----------+  +----------+      |
|                   | | Meeting  |->| Minutes  |->| Req      |->| Issues   |      |
|                   | | approved |  | review   |  | blocked  |  | locked   |      |
|                   | +----------+  +----------+  +----------+  +----------+      |
|                   |                                                            |
|                   | Review blockers                                           |
|                   | +------------------------------------------------------+   |
|                   | | P0 Requirement has 2 open questions                  |   |
|                   | | P0 GitHub integration is not connected               |   |
|                   | | P1 Minutes review action is unresolved               |   |
|                   | +------------------------------------------------------+   |
|                   |                                                            |
|                   | Recent artifacts                 Recent audit events       |
|                   | +----------------------------+   +----------------------+   |
|                   | | Latest meeting             |   | Generated minutes    |   |
|                   | | Requirement draft          |   | Review created       |   |
|                   | | Issue draft                |   | Issue draft edited   |   |
|                   | +----------------------------+   +----------------------+   |
+-------------------+------------------------------------------------------------+
```

### 主要操作

- Add Meeting
- Open latest blocker
- Continue pipeline
- Connect GitHub
- Export artifacts

### 空状態

```text
No meetings yet
[Add Meeting] [Load sample meeting]
```

### 失敗状態

- GitHub連携失敗: top barとReview blockersの両方に表示する。
- AI生成失敗: Recent artifactsにfailed statusを表示し、該当artifactへ誘導する。

## Meeting Workspace

### 目的

会議ログ、AI議事録、決定事項、未決事項、アクションアイテム、レビュー状態を同時に扱う。

### ワイヤーフレーム

```text
+--------------------------------------------------------------------------------+
| Meeting: 2026-06-30 Product Sync              [Generate Minutes] [Request Review]|
+-------------------+--------------------------+------------------+--------------+
| Sidebar           | Transcript               | Minutes editor   | Inspector    |
|                   |--------------------------|------------------|--------------|
|                   | Source: discord_log      | Summary          | Status       |
|                   | Participants: 4          | +--------------+ | generated    |
|                   |                          | | editable text| |              |
|                   | Raw log                  | +--------------+ | Review gate  |
|                   | +----------------------+ |                  | missing      |
|                   | | 10:00 K: ...         | | Decisions        |              |
|                   | | 10:02 A: ...         | | - ...            | Open Qs      |
|                   | | 10:05 T: ...         | |                  | - pricing?   |
|                   | +----------------------+ | Action items     | - scope?     |
|                   |                          | - owner/date     |              |
|                   | Secret scan: clear       |                  | Actions      |
|                   |                          |                  | [Approve]    |
|                   |                          |                  | [Regenerate] |
+-------------------+--------------------------+------------------+--------------+
```

### タブ

- Transcript
- Minutes
- Decisions
- Actions
- Review

### Review blocker表示

Meeting Workspaceでは、右Inspectorの最上部にReview gateを固定表示する。

```text
Review gate
Status: Review missing
Required: Minutes review
Blocking: Requirement generation
Next: Request Review
```

### 主要操作

- Generate Minutes
- Regenerate selected section
- Request Review
- Approve Minutes
- Generate Requirements

### 生成中

```text
Generating minutes
Step 1/4: Parsing transcript
Step 2/4: Extracting decisions
Step 3/4: Finding open questions
Step 4/4: Drafting summary
[Cancel]
```

### 生成失敗

```text
Minutes generation failed
Reason: AI generation timed out
[Retry] [Retry with shorter input] [View raw error]
```

### 部分再生成

ユーザーがsummary、decisions、open_questions、action_itemsのいずれかを選び、選択セクションだけ再生成できる。

```text
Regenerate selected section
Target: Open questions
Instruction: Keep confirmed decisions unchanged.
[Regenerate section]
```

## Requirement Workspace

### 目的

要件定義を編集し、Issue DraftとOpenAPI Draftに進められる品質まで上げる。

### ワイヤーフレーム

```text
+--------------------------------------------------------------------------------+
| Requirement: Meeting follow-up automation        [Request Review] [Approve]     |
+-------------------+------------------------------------------------+-----------+
| Sidebar           | Requirement editor                             | Inspector |
|                   |------------------------------------------------|-----------|
|                   | Background                                     | Status    |
|                   | +--------------------------------------------+ | in_review |
|                   | | editable text                              | |           |
|                   | +--------------------------------------------+ | Gate      |
|                   |                                                | blocked   |
|                   | Goal                                           |           |
|                   | +--------------------------------------------+ | Open Qs   |
|                   |                                                | 2         |
|                   | User stories                                   |           |
|                   | - As a founder...                             | Risks     |
|                   | - As a tech lead...                           | 3         |
|                   |                                                |           |
|                   | Functional requirements                        | Actions   |
|                   | - FR-001 ...                                  | [Resolve] |
|                   | - FR-002 ...                                  | [Review]  |
|                   |                                                |           |
|                   | Acceptance criteria                            | Generate  |
|                   | - Given...                                    | [Issue]   |
|                   | - When...                                     | [OpenAPI] |
+-------------------+------------------------------------------------+-----------+
```

### Review blocker rules

- open_questionsが1件以上ある場合、Issue/OpenAPI生成は警告付きで許可しない。
- P0 review actionが未解決の場合、Approve Requirementsを無効化する。
- accepted_riskは明示的な理由と承認者がある場合のみ次工程へ進める。

### 主要操作

- Request Expert Review
- Resolve review action
- Mark accepted risk
- Approve Requirements
- Generate Issue Draft
- Generate OpenAPI Draft

## Review Center

### 目的

レビュー結果と改善アクションをプロジェクト横断で管理する。MVPにおける中核画面。

### ワイヤーフレーム

```text
+--------------------------------------------------------------------------------+
| Reviews                                      Filter: [Open] [P0] [All roles]    |
+-------------------+------------------------------+-----------------------------+
| Sidebar           | Review list                  | Review detail               |
|                   |------------------------------|-----------------------------|
|                   | P0 Requirement               | Target: Requirement         |
|                   | Action required              | Framework: MoSCoW, WCAG     |
|                   | 2 open actions               | Reviewer: Product Manager   |
|                   |                              |                             |
|                   | P0 API Design                | Good points                 |
|                   | Action required              | - Clear pipeline            |
|                   | 4 open actions               | - Review gate included      |
|                   |                              |                             |
|                   | P1 Screen Design             | Improvements                |
|                   | Resolved                     | - Wireframe missing         |
|                   |                              | - Retry UX unclear          |
|                   |                              |                             |
|                   |                              | Actions                     |
|                   |                              | [ ] Create wireframe        |
|                   |                              | [ ] Define failure UX       |
|                   |                              |                             |
|                   |                              | [Mark resolved] [Issue]     |
+-------------------+------------------------------+-----------------------------+
```

### フィルター

- status: open, action_required, resolved, accepted_risk
- priority: P0, P1, P2
- target_type
- reviewer_role
- issue_number

### レビューアクション操作

- Mark resolved
- Mark accepted risk
- Create follow-up issue
- Request re-review
- Open target artifact

### Review Centerでの完了条件

P0 actionがすべてresolvedまたはaccepted_riskになり、対象artifactがapprovedになると次工程がunlockされる。

## Issue Draft Workspace

### ワイヤーフレーム

```text
+--------------------------------------------------------------------------------+
| Issue Draft: Implement meeting intake                  [Request Review] [Publish]|
+-------------------+-----------------------------------------------+------------+
| Sidebar           | GitHub issue editor                           | Inspector  |
|                   |-----------------------------------------------|------------|
|                   | Title                                         | Status     |
|                   | +-------------------------------------------+ | approved   |
|                   |                                               |            |
|                   | Body Markdown                                 | GitHub     |
|                   | +-------------------------------------------+ | connected  |
|                   | | Background                                | |            |
|                   | | Goal                                      | | Review     |
|                   | | Acceptance criteria                       | | clear      |
|                   | +-------------------------------------------+ |            |
|                   |                                               | Labels     |
|                   | Acceptance criteria                           | ai, mvp    |
|                   | - ...                                         |            |
|                   |                                               | Actions    |
|                   |                                               | [Publish]  |
|                   |                                               | [Copy]     |
+-------------------+-----------------------------------------------+------------+
```

### Publish gate

Publish to GitHubは以下をすべて満たす場合のみ有効。

- IssueDraft status is approved
- GitHub integration is connected
- No P0 review action remains open
- Title and body are not empty

## OpenAPI Draft Workspace

### ワイヤーフレーム

```text
+--------------------------------------------------------------------------------+
| OpenAPI Draft: Meeting API                  [Validate] [Request Review] [Export] |
+-------------------+-------------------------------+---------------+------------+
| Sidebar           | Endpoint list                 | YAML editor   | Inspector  |
|                   |-------------------------------|---------------|------------|
|                   | GET /projects                 | openapi: 3.1  | Status     |
|                   | POST /projects                | info:         | valid      |
|                   | POST /meetings                | paths:        |            |
|                   | POST /generate-minutes        | ...           | Validation |
|                   |                               |               | clear      |
|                   |                               |               |            |
|                   |                               |               | Review     |
|                   |                               |               | missing    |
|                   |                               |               |            |
|                   |                               |               | Actions    |
|                   |                               |               | [Approve]  |
+-------------------+-------------------------------+---------------+------------+
```

### Validation UX

OpenAPI Draftはレビュー前にvalidationを実行する。

```text
Validation failed
3 errors
- paths./meetings.post.responses.201 is missing schema
- components.schemas.Meeting.raw_text exceeds max length policy
- security requirement missing for publish endpoint
[Jump to first error] [Copy errors]
```

## Review blocker UX

### 定義

Review blockerは、次工程へ進む前に解消または明示承認が必要なレビュー指摘である。

### 種別

| Type | Meaning | Blocks |
| --- | --- | --- |
| review_missing | 必須レビューが未実施 | 次工程 |
| action_required | 改善アクションが未解決 | 承認、公開、実装 |
| open_question | 未決事項が残っている | Issue/OpenAPI生成 |
| validation_failed | 構文または仕様検証に失敗 | 承認、export |
| integration_error | 外部連携が失敗 | publish, sync |
| security_warning | 秘密情報や権限過剰の疑い | AI送信、publish |

### Severity

| Severity | UI | Behavior |
| --- | --- | --- |
| P0 | red status, fixed blocker | hard block |
| P1 | amber status, warning | block approval unless accepted risk |
| P2 | neutral status | does not block, shown in review |

### 表示場所

- Top bar: project全体の件数
- Context bar: 現在artifactのgate状態
- Right inspector: 詳細
- Review Center: 一覧と解決操作

### 標準文言

```text
Review required
This artifact cannot move to the next phase until required review actions are resolved.
```

```text
Blocked by open questions
Resolve or mark each question as accepted risk before generating Issue or OpenAPI drafts.
```

```text
GitHub connection required
Connect a GitHub repository before publishing approved issue drafts.
```

### 解除条件

Review blockerは以下のいずれかで解除される。

- actionをresolvedにする
- accepted_riskとして理由、承認者、期限を保存する
- missing reviewを作成し、必要actionを解消する
- validationを成功させる
- integration errorを再接続または再試行で解消する

### accepted_risk要件

accepted_riskには以下を必須にする。

- reason
- approved_by
- expires_at
- linked_issue_number
- residual_risk

P0 security blockerはaccepted_risk不可とする。

## AI生成失敗と再試行UX

### 共通状態

```text
queued -> running -> succeeded
queued -> running -> failed
failed -> retrying -> succeeded
failed -> retrying -> failed
```

### 失敗理由カテゴリ

- ai_timeout
- ai_rate_limited
- invalid_input
- secret_detected
- output_validation_failed
- provider_unavailable
- unknown_error

### UIルール

- ユーザー向けmessageとdeveloper detailを分ける。
- 失敗したartifactは消さず、failed状態で残す。
- retry時は前回input hash、prompt version、modelを記録する。
- secret_detectedの場合はAIへ送信せず、該当箇所の確認を促す。
- output_validation_failedの場合は部分再生成か手動修正を選べる。

### 再試行メニュー

```text
Retry options
- Retry same input
- Retry with shorter context
- Retry selected section
- Edit input before retry
- Save failed draft and continue later
```

### 部分再生成対象

- Minutes: summary, decisions, open_questions, action_items
- Requirement: background, goal, user_stories, functional_requirements, acceptance_criteria, risks
- Issue Draft: title, body, acceptance_criteria, labels
- OpenAPI Draft: endpoint, schema, error response, examples

## レスポンシブ方針

MVPはデスクトップ業務アプリとして最適化する。

### Breakpoints

| Width | Behavior |
| --- | --- |
| 1440px+ | sidebar, main, inspectorを常時表示 |
| 1280pxから1439px | inspectorをやや狭くし、editor優先 |
| 1024pxから1279px | inspectorはdrawer化 |
| 768pxから1023px | read-only review中心。編集は制限付き |
| 767px以下 | MVPでは正式対応外。unsupported noticeを表示 |

### モバイル方針

初期MVPではスマートフォンでの長文編集を主用途にしない。ただしReview Centerの確認とコメント程度は将来P1で対応する。

## 実装時の注意

- 画面の主操作は1つに絞る。
- 右Inspectorは状態確認と次アクションに限定し、編集フォームを詰め込まない。
- Review blockerは閉じられない固定情報として扱う。
- 生成中に画面遷移してもjob状態を復元できる。
- failed artifactは削除ではなくretryまたはarchiveを選ばせる。
- AI生成物の手動編集は常に保存履歴の対象にする。

## 未解決

- 実際のビジュアルデザインシステム
- コンポーネント命名
- エディタライブラリ選定
- OpenAPI validationの実装ライブラリ
- Figma化するか、先に静的プロトタイプを作るか

