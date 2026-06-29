# 2026-06-30 デザインシステムと静的プロトタイプ

## 対象Issue

- ISSUE-009: フロントエンド用デザインシステムと静的プロトタイプを作る

## 目的

MVPの実装前に、AI PM PlatformのUIを構成する色、余白、タイポグラフィ、コンポーネント、状態、アクセシビリティ、静的プロトタイプを定義する。

## 静的プロトタイプ

配置:

- `prototype/index.html`
- `prototype/styles.css`

対象画面:

- Project Workspace
- Meeting Workspace
- Requirement Workspace
- Review Center

## UIトーン

静かで実務的なSaaS UIにする。AI生成を派手に見せるのではなく、レビュー、状態、未決事項、承認ゲートを読みやすくする。

## カラー

| Token | Value | Use |
| --- | --- | --- |
| bg | `#f6f7f4` | page background |
| surface | `#ffffff` | panels |
| surface_alt | `#eef2f1` | toolbar, table header |
| text | `#172026` | primary text |
| muted | `#667085` | secondary text |
| border | `#d8dedb` | borders |
| teal | `#0f766e` | approved, primary |
| blue | `#2563eb` | links, active nav |
| amber | `#b45309` | warning |
| red | `#be123c` | hard blocker |
| violet | `#6d28d9` | AI generation accent, limited use |

## タイポグラフィ

- Font stack: system UI
- Page title: 20px, 600
- Section title: 14px, 600
- Body: 14px, 400
- Small text: 12px, 400
- Line height: 1.45
- Letter spacing: 0

## 余白

- 4px: tight inline
- 8px: component inner
- 12px: compact panel
- 16px: standard panel
- 24px: page spacing

## Border radius

- Buttons: 6px
- Status chips: 999px
- Panels: 8px
- Inputs/editors: 6px

## コンポーネント

### Sidebar

- width: 240px
- active itemは左borderとblue textで示す
- nav item height: 36px
- 長いlabelは省略せず折り返し禁止、必要なら短い名称にする

### Top bar

- height: 56px
- project selector
- GitHub status
- global review gate status
- account menu

### Context bar

- artifact名
- status chip
- primary action
- secondary action menu

### Status chip

| Status | Color |
| --- | --- |
| draft | muted |
| generating | violet |
| in_review | blue |
| needs_changes | amber |
| approved | teal |
| failed | red |

### Review blocker

- P0: red left border, hard block text
- P1: amber left border, accepted risk option
- P2: neutral border, non-blocking
- 常に次アクションを1つ以上表示する

### Editor

- min height: 280px
- monospaceはOpenAPI YAMLのみ
- text editorはplain system font
- right inspectorと重ならない

### Review action list

- priority
- target
- action
- owner
- status
- linked issue

## キーボード操作

- Sidebar: Arrow up/down, Enter
- Primary action: Tabで到達可能
- Review actions: Spaceでチェック、Enterで詳細
- Editor: Escでtoolbarへ戻る
- Drawer: Escで閉じる

## フォーカス順

1. Skip to main
2. Project selector
3. Global status
4. Sidebar
5. Page primary action
6. Main editor/list
7. Inspector
8. Secondary actions

## レスポンシブ

| Width | Behavior |
| --- | --- |
| 1440px+ | sidebar, main, inspector常時表示 |
| 1280-1439px | inspector narrow |
| 1024-1279px | inspector drawer |
| 768-1023px | review/read-only中心 |
| 767px以下 | unsupported notice |

## 未解決

- 実装フレームワーク
- アイコンライブラリ
- エディタライブラリ
- OpenAPI validation UIの詳細
- 実ブラウザでのビジュアルQA

