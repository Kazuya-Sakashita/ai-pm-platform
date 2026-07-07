require "rails_helper"
require "digest"
require "openssl"

RSpec.describe "API V1 GitHub Webhooks", type: :request do
  let!(:webhook_secret) { "webhook-secret" }
  let!(:project) { create(:project, github_repo: "Kazuya-Sakashita/ai-pm-platform") }
  let!(:account) do
    create(
      :integration_account,
      project: project,
      github_installation_id: "123456",
      external_account_id: "123456",
      repository_owner: "Kazuya-Sakashita",
      repository_name: "ai-pm-platform"
    )
  end

  around do |example|
    GithubIntegration::WebhookRateLimiter.reset_fallback_store!
    with_env("GITHUB_WEBHOOK_SECRET" => webhook_secret) { example.run }
  ensure
    GithubIntegration::WebhookRateLimiter.reset_fallback_store!
  end

  describe "POST /api/v1/webhooks/github" do
    it "installation deletedを署名検証後にrevokedへ同期する" do
      payload = installation_payload(action: "deleted")

      post_webhook(payload: payload, event: "installation", delivery: "delivery-1")

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      delivery_digest = Digest::SHA256.hexdigest("delivery-1")
      expect(body.dig("data", "status")).to eq("accepted")
      expect(body.dig("data", "event")).to eq("installation")
      expect(body.dig("data", "delivery_digest")).to eq(delivery_digest)
      expect(body.dig("data")).not_to include("delivery_id")

      expect(account.reload.status).to eq("revoked")
      expect(account.last_error_safe).to eq("GitHub App installationが失効しました。")
      delivery = GithubWebhookDelivery.find_by!(delivery_digest: delivery_digest)
      expect(delivery.status).to eq("processed")
      expect(delivery.github_installation_id).to eq("123456")
      expect(delivery).to have_attributes(repository_full_name: nil)

      audit_log = project.audit_logs.find_by!(action: "github.webhook.installation_sync")
      expect(audit_log.actor_id).to eq("system")
      expect(audit_log.metadata).to include(
        "delivery_digest" => delivery_digest,
        "event" => "installation",
        "github_installation_id" => "123456",
        "repository" => "Kazuya-Sakashita/ai-pm-platform",
        "sync_status" => "revoked"
      )
      expect(audit_log.metadata).not_to include("delivery_id", "signature", "payload", "secret", "raw_payload")
    end

    it "同じdeliveryの再送では副作用を二重実行しない" do
      payload = installation_payload(action: "deleted")

      post_webhook(payload: payload, event: "installation", delivery: "delivery-duplicate")
      post_webhook(payload: payload, event: "installation", delivery: "delivery-duplicate")

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("duplicate_ignored")
      expect(GithubWebhookDelivery.count).to eq(1)
      expect(project.audit_logs.where(action: "github.webhook.installation_sync").count).to eq(1)
    end

    it "署名不正では検証前副作用を発生させない" do
      payload = installation_payload(action: "deleted")

      post "/api/v1/webhooks/github",
           params: payload,
           headers: github_headers(payload: payload, event: "installation", delivery: "delivery-bad-signature").merge(
             "X-Hub-Signature-256" => "sha256=invalid"
           )

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("github_webhook_signature_invalid")
      expect(account.reload.status).to eq("connected")
      expect(GithubWebhookDelivery.count).to eq(0)
      expect(project.audit_logs.where(action: "github.webhook.installation_sync")).to be_empty
    end

    it "rotation window中はprevious secret署名のdeliveryを受理する" do
      payload = installation_payload(action: "deleted")

      with_env("GITHUB_WEBHOOK_SECRET" => "new-webhook-secret", "GITHUB_WEBHOOK_PREVIOUS_SECRET" => webhook_secret) do
        post_webhook(payload: payload, event: "installation", delivery: "delivery-previous-secret", secret: webhook_secret)
      end

      expect(response).to have_http_status(:accepted)
      expect(account.reload.status).to eq("revoked")
      expect(GithubWebhookDelivery.last.delivery_digest).to eq(Digest::SHA256.hexdigest("delivery-previous-secret"))
    end

    it "secret未設定では検証前副作用を発生させない" do
      payload = installation_payload(action: "deleted")

      with_env("GITHUB_WEBHOOK_SECRET" => nil, "GITHUB_WEBHOOK_PREVIOUS_SECRET" => nil) do
        post_webhook(payload: payload, event: "installation", delivery: "delivery-secret-missing")
      end

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("github_webhook_secret_not_configured")
      expect(account.reload.status).to eq("connected")
      expect(GithubWebhookDelivery.count).to eq(0)
      expect(project.audit_logs.where(action: "github.webhook.installation_sync")).to be_empty
    end

    it "JSON不正ではdeliveryもpayloadも保存しない" do
      payload = "{invalid-json"

      post_webhook(payload: payload, event: "installation", delivery: "delivery-invalid-json")

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("github_webhook_payload_invalid")
      expect(account.reload.status).to eq("connected")
      expect(GithubWebhookDelivery.count).to eq(0)
      expect(project.audit_logs.where(action: "github.webhook.installation_sync")).to be_empty
    end

    it "payload size超過では署名検証後の副作用を発生させない" do
      payload = installation_payload(action: "deleted")

      with_env("GITHUB_WEBHOOK_MAX_BYTES" => "8") do
        post_webhook(payload: payload, event: "installation", delivery: "delivery-payload-too-large")
      end

      expect(response).to have_http_status(413)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("github_webhook_payload_too_large")
      expect(account.reload.status).to eq("connected")
      expect(GithubWebhookDelivery.count).to eq(0)
      expect(project.audit_logs.where(action: "github.webhook.installation_sync")).to be_empty
    end

    it "rate limit超過では署名検証後の副作用を発生させない" do
      payload = JSON.generate(zen: "rate limit")

      with_env("GITHUB_WEBHOOK_RATE_LIMIT_PER_MINUTE" => "1") do
        post_webhook(payload: payload, event: "ping", delivery: "delivery-rate-limit-1")
        expect(response).to have_http_status(:accepted)
        deliveries_count = GithubWebhookDelivery.count
        audit_logs_count = project.audit_logs.count

        post_webhook(payload: payload, event: "ping", delivery: "delivery-rate-limit-2")

        expect(response).to have_http_status(:too_many_requests)
        expect(response.headers["Retry-After"]).to eq("60")
        body = JSON.parse(response.body)
        expect(body.dig("error", "code")).to eq("github_webhook_rate_limited")
        expect(account.reload.status).to eq("connected")
        expect(GithubWebhookDelivery.count).to eq(deliveries_count)
        expect(project.audit_logs.count).to eq(audit_logs_count)
      end
    end

    it "重複deliveryはJSON parse前にduplicate_ignoredにする" do
      payload = JSON.generate(zen: "duplicate")

      post_webhook(payload: payload, event: "ping", delivery: "delivery-duplicate-before-parse")
      post_webhook(payload: "{invalid-json", event: "ping", delivery: "delivery-duplicate-before-parse")

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("duplicate_ignored")
      expect(GithubWebhookDelivery.count).to eq(1)
      expect(project.audit_logs.where(action: "github.webhook.installation_sync")).to be_empty
    end

    it "repository removedは対象repositoryのaccountだけをrevokedにする" do
      other_account = create(
        :integration_account,
        project: project,
        github_installation_id: "123456",
        external_account_id: "123456",
        repository_owner: "Kazuya-Sakashita",
        repository_name: "other-repo"
      )
      payload = JSON.generate(
        action: "removed",
        installation: installation_payload_hash.fetch(:installation),
        repositories_removed: [
          { full_name: "Kazuya-Sakashita/ai-pm-platform" }
        ]
      )

      post_webhook(payload: payload, event: "installation_repositories", delivery: "delivery-repo-removed")

      expect(response).to have_http_status(:accepted)
      expect(account.reload.status).to eq("revoked")
      expect(other_account.reload.status).to eq("connected")
      expect(project.audit_logs.where(action: "github.webhook.installation_sync").count).to eq(1)
    end

    it "repository addedでIssues write権限があればconnectedへ復旧する" do
      account.update!(
        status: "error",
        last_error_safe: "GitHub AppのIssues write権限がありません。",
        granted_permissions: { "metadata" => "read", "issues" => "read" }
      )
      payload = JSON.generate(
        action: "added",
        installation: installation_payload_hash.fetch(:installation),
        repositories_added: [
          { full_name: "Kazuya-Sakashita/ai-pm-platform" }
        ]
      )

      post_webhook(payload: payload, event: "installation_repositories", delivery: "delivery-repo-added")

      expect(response).to have_http_status(:accepted)
      expect(account.reload).to have_attributes(
        status: "connected",
        last_error_safe: nil
      )
      expect(account.granted_permissions).to include("issues" => "write")
      audit_log = project.audit_logs.find_by!(action: "github.webhook.installation_sync")
      expect(audit_log.metadata).to include("sync_status" => "connected")
    end

    it "installation repositoriesの未知actionは副作用なしでignoredにする" do
      payload = JSON.generate(
        action: "renamed",
        installation: installation_payload_hash.fetch(:installation),
        repositories_added: [
          { full_name: "Kazuya-Sakashita/ai-pm-platform" }
        ]
      )

      post_webhook(payload: payload, event: "installation_repositories", delivery: "delivery-repo-unknown-action")

      expect(response).to have_http_status(:accepted)
      expect(account.reload.status).to eq("connected")
      expect(GithubWebhookDelivery.last.status).to eq("ignored")
      expect(project.audit_logs.where(action: "github.webhook.installation_sync")).to be_empty
    end

    it "Issues write権限が失われたらerrorへ同期する" do
      payload = installation_payload(
        action: "new_permissions_accepted",
        permissions: { metadata: "read", issues: "read" }
      )

      post_webhook(payload: payload, event: "installation", delivery: "delivery-permission-change")

      expect(response).to have_http_status(:accepted)
      expect(account.reload.status).to eq("error")
      expect(account.granted_permissions).to include("issues" => "read")
      expect(account.last_error_safe).to eq("GitHub AppのIssues write権限がありません。")
      audit_log = project.audit_logs.find_by!(action: "github.webhook.installation_sync")
      expect(audit_log.metadata).to include(
        "sync_status" => "permission_error",
        "safe_error_code" => "permission_error"
      )
    end

    it "未対応eventは署名検証後にignoredとして受ける" do
      payload = JSON.generate(zen: "Keep it logically contained.")

      post_webhook(payload: payload, event: "ping", delivery: "delivery-ping")

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("accepted")
      expect(account.reload.status).to eq("connected")
      expect(GithubWebhookDelivery.last.status).to eq("ignored")
      expect(project.audit_logs.where(action: "github.webhook.installation_sync")).to be_empty
    end
  end

  def post_webhook(payload:, event:, delivery:, secret: webhook_secret)
    post "/api/v1/webhooks/github",
         params: payload,
         headers: github_headers(payload: payload, event: event, delivery: delivery, secret: secret)
  end

  def github_headers(payload:, event:, delivery:, secret: webhook_secret)
    {
      "CONTENT_TYPE" => "application/json",
      "X-GitHub-Event" => event,
      "X-GitHub-Delivery" => delivery,
      "X-Hub-Signature-256" => "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, payload)}"
    }
  end

  def installation_payload(action:, permissions: { metadata: "read", issues: "write" })
    JSON.generate(installation_payload_hash.merge(action: action, installation: installation_payload_hash.fetch(:installation).merge(permissions: permissions)))
  end

  def installation_payload_hash
    {
      action: "deleted",
      installation: {
        id: 123_456,
        account: {
          login: "Kazuya-Sakashita",
          type: "User"
        },
        permissions: {
          metadata: "read",
          issues: "write"
        }
      }
    }
  end
end
