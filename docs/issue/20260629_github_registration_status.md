# 2026-06-29 GitHub Issue登録状況

## 現在の状態

GitHub Issue登録は未完了。

2026-06-30 07:10 JST時点でも、remote未設定、GitHub CLI token invalidのため、GitHub同期は未完了。

## 実施済み

- `git init -b main` でローカルGitリポジトリを初期化した。
- `gh auth status` を確認した。
- `gh issue create --title "ISSUE-001: Project foundation, research, and governance" --body-file docs/issue/ISSUE-001_project_foundation_research_and_governance.md` を試行した。
- `scripts/sync-github-issues.rb` を追加し、Issue一括登録のdry-runとapply手順を用意した。
- `npm run github:issues:dry-run` で登録対象を確認できるようにした。

## ブロッカー

1. `gh issue create` が `no git remotes found` で失敗した。
2. `gh auth status` で GitHub token invalid が確認された。

## 必要な次アクション

1. GitHub CLIを再認証する。
2. GitHub repositoryを作成または既存repositoryをremoteとして設定する。
3. `git push -u origin main` で初回commitをpushする。
4. `npm run github:issues:dry-run` で登録対象を確認する。
5. `npm run github:issues:sync` で `docs/issue/ISSUE-*.md` をGitHub Issueとして登録する。
6. 登録後、各Issueファイルの `GitHub Issue` 欄へURLと番号を追記する。
7. `docs/review/` の `Issue番号` 欄へGitHub番号を追記する。

## 同期コマンド

```bash
gh auth login -h github.com
git remote add origin <repo-url>
git push -u origin main
npm run github:issues:dry-run
npm run github:issues:sync
```

## 既知の注意点

- `npm run github:issues:sync` はGitHub CLI認証とGit remoteが必要。
- すでにGitHub URLが入っているIssueファイルは登録対象から除外する。
- GitHub Issue作成後、Issueファイルの `GitHub Issue` 欄は自動更新される。
- Reviewファイル内のGitHub Issue番号反映は未自動化。

## 登録対象

- `docs/issue/ISSUE-001_project_foundation_research_and_governance.md`
- `docs/issue/ISSUE-002_discord_meeting_ingestion_mvp.md`
- `docs/issue/ISSUE-003_minutes_to_requirements_pipeline.md`
- `docs/issue/ISSUE-004_github_issue_and_openapi_pipeline.md`
- `docs/issue/ISSUE-005_ai_review_and_evaluation_pipeline.md`
- `docs/issue/ISSUE-006_security_auth_and_audit_baseline.md`
- `docs/issue/ISSUE-007_mvp_wireframes_and_review_blocker_ux.md`
- `docs/issue/ISSUE-008_api_db_design_hardening_before_implementation.md`
- `docs/issue/ISSUE-009_frontend_design_system_and_static_prototype.md`
- `docs/issue/ISSUE-010_github_integration_auth_decision.md`
- `docs/issue/ISSUE-011_static_prototype_visual_qa_and_frontend_preparation.md`
- `docs/issue/ISSUE-012_github_app_implementation_preparation.md`
- `docs/issue/ISSUE-013_backend_frontend_implementation_preparation.md`
- `docs/issue/ISSUE-014_monorepo_scaffold_and_openapi_tooling.md`
- `docs/issue/ISSUE-015_backend_projects_meetings_reviews_jobs_mvp.md`
- `docs/issue/ISSUE-016_openapi_lint_codegen_decision.md`
- `docs/issue/ISSUE-017_openapi_tooling_implementation.md`
- `docs/issue/ISSUE-018_openapi_lint_warnings_cleanup.md`
- `docs/issue/ISSUE-019_node_toolchain_version_policy.md`
- `docs/issue/ISSUE-020_github_repository_and_issue_sync.md`
