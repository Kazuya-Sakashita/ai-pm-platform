# Backend

Rails API for the AI PM Platform.

初期実装順:

1. Rails API scaffold
2. PostgreSQL connection
3. Projects
4. Meetings
5. Reviews
6. Jobs
7. Audit logs

実装前の根拠:

- `docs/architecture/20260630_backend_frontend_implementation_preparation.md`
- `docs/api/openapi.yaml`

## Local commands

```bash
docker compose up -d db
bundle install
bundle exec rails db:prepare
bundle exec rspec
```

The API is mounted under `/api/v1`.

`ai_pm_password` is a local Docker development password only. Production must use `DATABASE_URL`.

## Background jobs

Production uses Solid Queue as the ActiveJob backend.

```bash
bundle exec rails db:prepare
bundle exec bin/jobs
```

Set `QUEUE_DATABASE_URL` when the queue database should be separated from the primary application database. See `docs/release/20260703_solid_queue_operations_runbook.md` for the operations checklist.

## GitHub App issue publishing

Default behavior is safe-disabled. Set the following variables only after a GitHub App is installed for the target repository and an `integration_accounts` row exists for that project.

```bash
GITHUB_ISSUE_PUBLISH_PROVIDER=github_app
GITHUB_APP_ID=123456
GITHUB_APP_SLUG=ai-pm-platform
GITHUB_APP_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
# or
GITHUB_APP_PRIVATE_KEY_BASE64="base64-encoded-pem"
# optional, when the app uses a custom installation URL
GITHUB_APP_INSTALLATION_URL="https://github.com/apps/ai-pm-platform/installations/new"
```

Required GitHub App permissions:

- Metadata: read
- Issues: write

Installation access tokens are generated on demand and are not stored.
