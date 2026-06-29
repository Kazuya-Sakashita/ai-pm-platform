# Frontend

Next.js App Router frontend。

## 起動

```bash
npm run frontend:dev
```

Frontend:

- http://localhost:3000

API:

- `NEXT_PUBLIC_API_BASE_URL` 未設定時は `http://localhost:3001/api/v1`

## 検証

```bash
npm run frontend:build
npm run api:verify
```

## 実装済み

- Meeting Workspace
- Project作成/選択
- Meeting保存
- Minutes生成
- Job取得
- Minutes取得/編集/承認
- Review作成

## 未完了

- Playwright smoke tests
- ブラウザスクリーンショットによるビジュアルQA
- Review Center本体との接続
- 認証/テナント境界

## 根拠

- `docs/product/20260630_design_system_and_static_prototype.md`
- `prototype/index.html`
