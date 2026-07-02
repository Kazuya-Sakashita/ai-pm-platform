# Discord DM手動インポートとAI整理MVP 要件定義

## 目的

Discord DMで発生した仕様相談、意思決定、依頼、TODOを、ユーザーが明示的に取り込み、AI PM Platform上で安全に整理する。整理結果はそのまま実装へ流さず、レビュー後に議事録、要件、GitHub Issue候補へ接続する。

## 対象ユーザー

- Discordで個別相談を受ける開発者、PM、PdM
- クライアントやメンバーとのDMから仕様・TODOを拾いたい小規模チーム
- 会議よりもチャットで意思決定が進むスタートアップ/開発チーム

## ユーザーストーリー

- ユーザーとして、Discord DMの一部を貼り付けて、AIに整理してほしい。
- ユーザーとして、AIへ送る前に個人情報や秘密情報を確認・削除したい。
- ユーザーとして、DM相手の同意を得たことを明示してから保存したい。
- PMとして、DMから決定事項、未決事項、TODO、Issue候補を抽出したい。
- Tech Leadとして、DM由来の要件がどの会話から来たか監査したい。
- Security Engineerとして、DM全文が無制限に外部AIへ送られないことを確認したい。

## MVP機能

1. DM手動貼り付け
   - source typeは `discord_dm_paste`
   - title、参加者表示名、会話日時、raw textを入力できる
   - 添付ファイルはMVPでは扱わない

2. 同意確認
   - 「このDMを取り込む権限/同意がある」ことを明示チェックする
   - 同意確認者、確認日時、確認文言versionをAuditLogへ保存する

3. インポート前編集
   - raw textを保存前に編集できる
   - 個人情報、トークン、URL、メールアドレスらしき文字列を検出する
   - 検出時はAI整理実行前にredactionまたは明示承認が必要

4. AI整理ドラフト
   - summary
   - decisions
   - open_questions
   - action_items
   - issue_candidates
   - requirement_candidates
   - risks
   - participants
   - confidence
   - source_quotes

5. レビューゲート
   - AI整理結果は `draft` として保存する
   - ユーザーが編集・承認するまでIssue生成へ進めない
   - レビュー結果は `docs/review/` 形式とDB Reviewの両方へ接続できる設計にする

6. 監査ログ
   - import created
   - redaction applied
   - AI summary generated
   - review requested
   - review approved/rejected
   - issue candidates generated

## 非機能要件

- DM raw textは高センシティブデータとして扱う
- AI送信前にsecret scanを必須にする
- 最小権限でプロジェクトメンバーだけが閲覧できる
- raw textとAI出力の削除/保持期間を後続Issueで設計する
- 生成結果には引用根拠を残し、誤要約をレビューで修正できる
- large pasteは文字数上限を設け、分割処理または拒否する

## 非スコープ

- Discord DM自動取得
- Discordユーザーアカウントの自動操作
- Discord botがDM履歴を横断取得すること
- 添付ファイルOCR/画像解析
- 相手方同意管理の法的ワークフロー完全実装
- Slack/Notion/Google Driveへの自動転送

## 成功指標

- DM貼り付けから整理ドラフト作成まで2分以内
- AI整理結果の手動修正率が初回MVPで50%未満
- DM由来Issue候補の採用率が30%以上
- secret/PII検出時のブロック率と解除理由が監査できる
- レビューなしIssue化が0件

## リスク

- 相手方同意なしのDM取り込み
- 個人情報や秘密情報のAI送信
- AIによる誤要約、発言者取り違え
- DM文脈不足による誤ったIssue化
- Discord API制約を誤解した自動取得実装

## 次フェーズ

- OpenAPI draft
- DB設計
- UIワイヤーフレーム
- AI prompt/schema
- 実装前セキュリティレビュー
