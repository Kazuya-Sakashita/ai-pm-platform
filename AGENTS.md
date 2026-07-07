# AGENTS.md

このプロジェクトは、AIを活用した議事録プラットフォームから AI Project Manager へ発展させるための開発ルールを定義する。

このファイルは、リポジトリ内の開発判断における最優先ルールである。ただし、システム指示、開発者指示、ユーザーからの明示指示がある場合はそれらを優先する。

## 目的

会議から、議事録、要件定義、Issue生成、API設計、実装、レビュー、テスト、リリースまでを、監査可能なAI支援ワークフローとして自動化する。

最終目標は、開発チームのPM、PdM、Tech Lead、QA、Security、Release Manager の一部機能を代替または補強する AI PM を実現することである。

## 最重要ルール

1. レビューなしで次工程へ進んではならない。
2. Issueなしで実装してはならない。
3. API駆動開発を守る。
4. 評価は世界レベルのSaaSを基準にし、必ず改善点と改善案を出す。
5. Codexは実装者だけでなく、プロジェクト全体を評価、改善、統制する役割を担う。
6. すべての重要判断は文書化する。
7. セキュリティ、品質、UX、保守性、拡張性、AI活用、ドキュメント、レビュー結果を完成条件に含める。

## 言語運用ルール

このプロジェクトの運用言語は日本語を標準とする。

以下は原則として日本語で作成、更新、報告する。

- コミットメッセージ
- Pull Requestのタイトル、本文、コメント
- GitHub Issueのタイトル、本文、コメント
- レビュー文書
- ADR、設計書、Runbook、Issue台帳
- 作業報告、最終報告、補足説明
- コードコメント
- UI表示文言、エラーメッセージ、ステータス表示

ただし、以下は英語または既存表記を維持してよい。

- クラス名、関数名、変数名、型名、ファイル名
- API path、schema名、error code、status code
- Git branch名、package名、ライブラリ名、外部サービス名
- GitHubの自動クローズキーワードなど、機械処理に必要な定型句
- コマンド、ログ、CI出力、例外メッセージなど外部ツール由来の文言
- 既存コード規約やフレームワーク慣習上、英語の方が明確な短い技術用語

完了前には、不要な英語のコミットメッセージ、PR本文、Issue本文、レビュー文書、UI文言、コードコメントが混入していないか確認する。英語が必要な場合は、識別子、API契約、外部ツール出力などの例外に該当することを確認する。

英語のコミットメッセージやPR本文を作成してしまった場合は、GitHub上で安全に修正できるタイトル、本文、コメントを先に日本語化する。すでに共有済みのmain履歴を書き換える必要がある場合は、force pushのリスクを明記し、ユーザーの明示承認なしに実行してはならない。

## 標準フェーズ

以下の各フェーズ終了時に、必ず `docs/review/` へレビューを保存する。

1. 市場調査
2. 競合分析
3. 要件定義
4. 画面設計
5. API設計
6. DB設計
7. 実装
8. レビュー
9. テスト
10. リリース

レビューがないフェーズは未完了として扱う。

## レビュー保存ルール

レビュー結果は `docs/review/YYYYMMDD_xxx_review.md` として保存する。

各レビューには必ず以下を含める。

- 評価日時
- 評価担当
- 使用フレームワーク
- 良かった点
- 改善点
- 優先順位
- 次アクション
- Issue番号

## Issue駆動開発

すべての実装、仕様変更、設計変更は Issue を起点にする。

Issueは `docs/issue/` に保存し、以下を含める。

- Issue番号
- GitHub Issue URLまたは登録待ち理由
- 背景
- 目的
- 完了条件
- スコープ
- 非スコープ
- 関連レビュー
- レビュー結果
- 次アクション

GitHub登録ができない場合は、登録できない理由をIssueファイルに明記し、登録可能になったら同じ内容でGitHub Issueへ同期する。

## API駆動開発

開発は以下の順番を守る。

1. Issue
2. 要件定義
3. OpenAPI
4. レビュー
5. 修正
6. Backend
7. Frontend
8. レビュー
9. 修正
10. テスト
11. レビュー
12. マージ

OpenAPIと実装が乖離した状態で完了扱いにしてはならない。

## Rails責務分離ルール

Rails実装に入る前に、Controller / Model に処理を詰め込みすぎないか必ず確認する。

基本方針:

- Controller: リクエスト受付、認可、入力受け取り、レスポンス返却に限定する。
- Model: DBに紐づく基本的なルール、関連、短いscopeに限定する。
- Service Object: 業務処理をまとめる。
- Result Object: 成功、失敗、エラー理由を返す。
- Query / Finder Object: 検索条件や一覧取得をまとめる。
- Form Object: 複数モデルや画面専用入力を扱う。
- Validator Object: 複雑な検証ロジックを切り出す。
- Serializer: APIレスポンスのJSON形式を定義する。
- Policy Object: 権限判定を分離する。
- Adapter / Gateway: 外部API、Slack、決済、メールなど外部連携を分離する。
- DI: 外部サービス依存はテストで差し替えられるようにする。
- Strategy Pattern: 通知方法、決済方法など処理を切り替える。
- State Pattern: 状態ごとの振る舞いが増えたら分離する。
- Value Object: 金額、日付範囲、表示名など値にルールがある場合に使う。
- Null Object: nil分岐が多い場合に検討する。ただしログイン必須処理では慎重に使う。

ただし、過剰設計は禁止する。短く単純な処理は無理にクラス化しない。

Rails実装時は、作業前または最終報告で必ず以下を示す。

1. 今回の責務分離方針
2. どの処理をどこに置いたか
3. 過剰設計を避けた理由
4. テスト方針
5. 変更ファイル一覧

## ADR

技術選定、アーキテクチャ、データ保存、外部連携、AIモデル、セキュリティ方針など、後から振り返る価値がある判断は `docs/decisions/` に ADR として保存する。

## 専門家レビュー体制

Codexは、必要に応じて以下の専門家ロールの観点で評価する。

- Product Owner: 市場価値、MVP、競合、収益
- CTO: アーキテクチャ、技術負債、拡張性
- Tech Lead: 設計、API、レビュー、品質
- AI Architect: OpenAI、Codex、MCP、Agent、Prompt
- Backend Architect: Rails、Prisma、DB、OpenAPI
- Frontend Architect: Next.js、React、UX、アクセシビリティ
- DevOps: Docker、CI/CD、IaC
- Security Engineer: OAuth、認証、OWASP、監査
- QA: RSpec、Playwright、品質保証
- UI/UX Designer: デザイン、導線、Figma、ユーザビリティ
- Product Manager: ロードマップ、優先順位、リスク
- Business Consultant: 価格戦略、営業戦略、事業性
- Startup Advisor: 資金調達、IPO、組織、スケール

## 専門家サブエージェントレビュー運用

重要Issueでは、専門家レビューを単一の総合コメントで終わらせず、必要に応じて専門家サブエージェントまたはロール分離レビューとして実施する。

全サブエージェントは、各自の専門領域だけでなく、以下6つの共通評価軸への影響を必ず確認する。

1. 強固なセキュリティ: Security by Design、OWASP Top 10、最小権限、認証、認可、入力値検証、監査ログ、秘密情報管理を確認する。
2. 高い技術品質: 保守性、拡張性、可読性、テスト容易性、パフォーマンスを確認する。
3. 優れたユーザー体験: 直感的な操作、ストレスの少ないUI/UX、アクセシビリティ、日本語表示品質を確認する。
4. 継続して利用したくなる体験: 習慣化、エンゲージメント、再訪価値、運用負荷を確認する。
5. 事業としての価値: ユーザー課題、差別化、導入価値、成長可能性を確認する。
6. 長期運用できる設計: 将来拡張、技術的負債、安定運用、監査性、障害対応を確認する。

技術的に実装可能であることだけを合格条件にしてはならない。ユーザー、開発者、運営者の三者にとって長期的に価値があるかを判断基準に含める。

この運用は、Issue駆動、API駆動、レビュー保存、Security/QA blocker、Skill Hub優先順位を弱めるものではない。詳細な運用は `docs/ai/expert_subagents.md` と `docs/evaluation/expert_review_schema.md` に従う。

運用レベル:

- L1: Codex内のロール分離レビュー
- L2: Codexサブエージェントによる独立レビュー
- L3: Codex、Claude、ChatGPTなど外部AIを含む比較レビュー

以下はL2以上を推奨する。

- 認証、認可、監査、個人情報、秘密情報、データ削除に関わる
- AI provider、prompt、Structured Outputs、Agent設計に関わる
- OpenAPI、DB設計、API contract、ジョブ基盤に関わる
- production smoke、リリース、障害対応に関わる
- P0/P1 Issue、または次工程の判断に強く影響する

専門家サブエージェントレビューでは以下を守る。

- 各Agentは独立した合否、重大リスク、改善案を出す。
- Security EngineerとQAのP0 blockerは、明示的なリスク受容なしに次工程へ進めない。
- Review Orchestratorは指摘を採用、保留、却下、追加調査へ分類し、判断理由を残す。
- schema-invalid、根拠なし、低confidence、対象成果物不明、Issue番号なしのレビューは完了条件を満たさない。
- 外部AIが利用できない場合は、Codex一次レビューとして保存し、外部AIレビュー待ちであることを明記する。
- raw chain-of-thought、secret、token、不要なPII、DM原文全文をレビュー記録へ保存してはならない。

詳細は以下に従う。

- `docs/ai/expert_subagents.md`
- `docs/evaluation/expert_review_schema.md`

## 使用フレームワーク

レビュー時は課題に合わせて最適なフレームワークを選ぶ。

- G-STACK
- HEART
- RICE
- MoSCoW
- SWOT
- PEST
- Five Forces
- Lean Canvas
- Business Model Canvas
- DDD
- Event Storming
- C4 Model
- ADR
- STRIDE
- OWASP Top 10
- WCAG
- ISO25010
- DORA Metrics
- SPACE Framework

## AIレビュー方針

理想状態では Codex、Claude、ChatGPT など複数AIでレビューし、差分を比較する。

外部AIをこの環境から直接実行できない場合は、Codexレビューを一次レビューとして保存し、外部AIレビュー待ちであることを明記する。外部レビュー結果が追加された場合は、相違点、判断根拠、採用方針を追記する。

## ドキュメント配置

- `docs/architecture/`: アーキテクチャ、C4、システム構成
- `docs/api/`: OpenAPI、API設計レビュー
- `docs/issue/`: Issue台帳、GitHub Issue同期記録
- `docs/meeting/`: 会議ログ、議事録サンプル
- `docs/review/`: フェーズレビュー、AIレビュー比較
- `docs/evaluation/`: 評価基準、フレームワーク
- `docs/roadmap/`: ロードマップ、マイルストーン
- `docs/decisions/`: ADR
- `docs/security/`: セキュリティ、脅威分析、監査
- `docs/ai/`: AI設計、プロンプト、エージェント設計
- `docs/product/`: プロダクト要件、MVP、勝ち筋
- `docs/research/`: 市場調査、競合分析、ユーザー調査
- `docs/release/`: リリース計画、リリースノート

## 完成条件

動作するだけでは完成ではない。以下を満たすこと。

- 保守性がある
- 拡張性がある
- 品質が一定以上である
- 可読性がある
- テストがある
- UXが妥当である
- UIが一貫している
- セキュリティ観点の確認がある
- AI活用がプロダクト価値に直結している
- ドキュメントが更新されている
- レビュー結果と改善対応が残っている
