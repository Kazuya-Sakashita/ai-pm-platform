# 2026-06-30 Backend/Frontend実装準備

## 対象Issue

- ISSUE-013: Backend/Frontend実装準備を行う

## 目的

実装へ進む前に、モノレポ構成、Rails API、Next.js、OpenAPI lint/codegen、DB migration、テスト、CIの最小構成を決める。

## 推奨リポジトリ構成

```text
.
├── AGENTS.md
├── docker-compose.yml
├── docs/
├── frontend/
│   ├── app/
│   ├── components/
│   ├── lib/
│   ├── e2e/
│   ├── package.json
│   └── playwright.config.ts
├── backend/
│   ├── app/
│   ├── config/
│   ├── db/
│   ├── spec/
│   ├── Gemfile
│   └── Dockerfile
├── scripts/
│   ├── check-api-types.mjs
│   └── lint-openapi.mjs
└── prototype/
```

## Backend

推奨:

- Rails API
- PostgreSQL
- ActiveRecord
- ActiveRecord Encryption
- RSpec
- FactoryBot
- request specs
- service objects for GitHub App and AI generation

### 初期domain modules

- Projects
- Meetings
- Minutes
- Requirements
- IssueDrafts
- OpenApiDrafts
- Reviews
- Integrations
- Jobs
- AuditLogs
- SecurityScans

### Backend実装順

1. Rails API scaffold
2. PostgreSQL connection
3. authentication placeholder
4. projects/meetings CRUD
5. jobs model
6. reviews/review actions
7. issue drafts
8. OpenAPI drafts and validation placeholder
9. GitHub App integration skeleton
10. audit logs
11. secret scan placeholder

## Frontend

推奨:

- Next.js
- React
- TypeScript
- App Router
- Playwright
- OpenAPI generated client
- CSS ModulesまたはTailwindは実装前に決定

### 初期画面

- Project Workspace
- Meeting Workspace
- Requirement Workspace
- Review Center
- Integration Settings

### Frontend実装順

1. Next.js scaffold
2. shared layout
3. design tokens
4. static data version of prototype
5. API client integration
6. Meeting create flow
7. Review blocker UI
8. GitHub integration status UI
9. Playwright smoke tests

## OpenAPI lint/codegen

OpenAPIを実装の中心にする。

### 方針

- `docs/api/openapi.yaml` を契約の正とする
- Backend request specはOpenAPIと乖離しないようにする
- Frontend API clientはOpenAPIから生成する
- 生成物はCIで差分検出する

### 候補

- OpenAPI lint: Redocly CLI or Spectral
- TypeScript client: openapi-typescript
- Backend validation: committee or rswag

MVPでは軽量に始めるため、まずOpenAPI lintとTypeScript型生成を優先する。

## DB migration方針

初期migration対象:

- organizations
- users
- memberships
- projects
- meetings
- minutes
- requirements
- issue_drafts
- openapi_drafts
- reviews
- review_actions
- accepted_risks
- integration_accounts
- jobs
- artifact_versions
- secret_scan_results
- ai_generations
- audit_logs

### 方針

- UUID primary key
- enumはRails enumまたはstring enumから開始
- 外部連携tokenは暗号化
- raw_textとAI出力は暗号化
- audit_logsにはsafe_metadataのみ保存
- GitHub publish idempotencyはunique indexで保証

## GitHub App実装反映

OpenAPIへ追加済み:

- `POST /webhooks/github`

DB設計へ反映する項目:

- github_installation_id
- repository_owner
- repository_name
- github_account_login
- github_account_type
- publish_idempotency_key
- github_issue_node_id
- github_issue_api_id

## Testing

### Backend

- model specs
- request specs
- service specs
- GitHub API mock specs
- webhook signature specs
- idempotency specs
- encryption/redaction specs

### Frontend

- Playwright smoke test
- Review blocker rendering
- Meeting Workspace rendering
- mobile unsupported notice
- GitHub disconnected state

### Contract

- OpenAPI YAML parse
- schema reference check
- generated client is up to date
- request spec samples match OpenAPI

## CI minimal

Jobs:

1. openapi
   - parse YAML
   - lint
   - generated type diff check
2. backend
   - bundle install
   - rails db:prepare
   - rspec
3. frontend
   - npm ci
   - typecheck
   - lint
   - Playwright smoke

## Docker

Initial services:

- backend
- frontend
- db

Future:

- worker
- redis or Solid Queue backend

## Environment variables

Backend:

- DATABASE_URL
- RAILS_MASTER_KEY or credentials equivalent
- OPENAI_API_KEY
- GITHUB_APP_ID
- GITHUB_APP_CLIENT_ID
- GITHUB_APP_CLIENT_SECRET
- GITHUB_APP_PRIVATE_KEY
- GITHUB_APP_WEBHOOK_SECRET
- GITHUB_APP_CALLBACK_URL
- GITHUB_APP_WEBHOOK_URL

Frontend:

- NEXT_PUBLIC_API_BASE_URL

## Implementation gate

実装へ進む条件:

- OpenAPI YAML validation passes
- GitHub App ADR accepted
- DB hardening accepted
- static prototype visual QA accepted
- implementation preparation review saved
- implementation Issue created

## 未解決

- CSS Modules vs Tailwind
- GitHub API client library
- OpenAPI lint/codegen tool final selection
- background job engine
- auth provider

