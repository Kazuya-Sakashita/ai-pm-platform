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
