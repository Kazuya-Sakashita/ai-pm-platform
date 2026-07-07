require "digest"
require "json"

module GithubIntegration
  class WebhookProcessor
    Result = Struct.new(:status, :delivery_digest, :event, keyword_init: true)

    SUPPORTED_EVENTS = %w[installation installation_repositories].freeze
    SAFE_PERMISSION_KEYS = %w[metadata issues contents pull_requests administration].freeze
    REVOKED_ACTIONS = %w[deleted suspend].freeze
    REFRESH_ACTIONS = %w[created unsuspend new_permissions_accepted].freeze
    REPOSITORY_ACTIONS = %w[added removed].freeze

    def call(event:, delivery_id:, payload:)
      parsed_payload = parse_payload(payload)
      normalized_event = event.to_s
      delivery_digest = digest_delivery_id(delivery_id)
      installation_id = installation_id(parsed_payload)
      repository = primary_repository(parsed_payload)

      delivery, duplicate = find_or_create_delivery(
        delivery_digest: delivery_digest,
        event: normalized_event,
        installation_id: installation_id,
        repository: repository,
        payload: parsed_payload
      )
      return Result.new(status: "duplicate_ignored", delivery_digest: delivery.delivery_digest, event: delivery.event) if duplicate

      process_delivery!(delivery, parsed_payload)
      Result.new(status: "accepted", delivery_digest: delivery.delivery_digest, event: delivery.event)
    rescue ActiveRecord::RecordInvalid => e
      raise WebhookError.new(
        code: "github_webhook_delivery_invalid",
        message: e.message,
        safe_detail: "GitHub Webhook deliveryを記録できませんでした。"
      )
    end

    private

    def parse_payload(payload)
      JSON.parse(payload.to_s)
    rescue JSON::ParserError
      raise WebhookError.new(
        code: "github_webhook_payload_invalid",
        message: "GitHub Webhook payloadがJSONとして不正です。",
        safe_detail: "GitHub Webhook payloadが不正です。"
      )
    end

    def digest_delivery_id(delivery_id)
      raw_delivery_id = delivery_id.to_s
      raise WebhookError.new(
        code: "github_webhook_delivery_missing",
        message: "GitHub Webhook delivery idが不足しています。",
        safe_detail: "GitHub Webhook delivery idが不足しています。"
      ) if raw_delivery_id.blank?

      Digest::SHA256.hexdigest(raw_delivery_id)
    end

    def find_or_create_delivery(delivery_digest:, event:, installation_id:, repository:, payload:)
      existing_delivery = GithubWebhookDelivery.find_by(delivery_digest: delivery_digest)
      return [existing_delivery, true] if existing_delivery

      [
        GithubWebhookDelivery.create!(
          delivery_digest: delivery_digest,
          event: event,
          status: "processing",
          github_installation_id: installation_id,
          repository_full_name: repository,
          metadata: {
            action: payload["action"],
            supported_event: SUPPORTED_EVENTS.include?(event)
          }.compact
        ),
        false
      ]
    rescue ActiveRecord::RecordNotUnique
      [GithubWebhookDelivery.find_by!(delivery_digest: delivery_digest), true]
    end

    def process_delivery!(delivery, payload)
      unless SUPPORTED_EVENTS.include?(delivery.event)
        delivery.update!(status: "ignored", processed_at: Time.current)
        return
      end

      affected_count = case delivery.event
      when "installation"
        process_installation_event(payload, delivery)
      when "installation_repositories"
        process_installation_repositories_event(payload, delivery)
      end

      delivery.update!(
        status: affected_count.positive? ? "processed" : "ignored",
        processed_at: Time.current,
        metadata: delivery.metadata.merge(affected_accounts_count: affected_count)
      )
    rescue WebhookError => e
      delivery.update!(
        status: "failed",
        safe_error_code: e.code,
        processed_at: Time.current
      )
      raise
    end

    def process_installation_event(payload, delivery)
      action = payload["action"].to_s
      installation_id = required_installation_id(payload)
      permissions = safe_permissions(payload.dig("installation", "permissions"))
      accounts = IntegrationAccount.where(provider: "github", github_installation_id: installation_id)
      return 0 unless REFRESH_ACTIONS.include?(action) || REVOKED_ACTIONS.include?(action)

      affected = 0
      accounts.find_each do |account|
        if REVOKED_ACTIONS.include?(action)
          update_account!(
            account: account,
            status: "revoked",
            permissions: permissions.presence || account.granted_permissions,
            safe_error: "GitHub App installationが失効しました。",
            delivery: delivery,
            sync_status: "revoked"
          )
        else
          sync_account_permissions!(
            account: account,
            permissions: permissions,
            delivery: delivery
          )
        end
        affected += 1
      end
      affected
    end

    def process_installation_repositories_event(payload, delivery)
      action = payload["action"].to_s
      return 0 unless REPOSITORY_ACTIONS.include?(action)

      installation_id = required_installation_id(payload)
      permissions = safe_permissions(payload.dig("installation", "permissions"))
      repositories = repositories_for_action(payload, action)
      return 0 if repositories.empty?

      affected = 0
      repositories.each do |repository|
        accounts = accounts_for_repository(installation_id: installation_id, repository: repository)
        accounts.find_each do |account|
          if action == "removed"
            update_account!(
              account: account,
              status: "revoked",
              permissions: permissions.presence || account.granted_permissions,
              safe_error: "GitHub repository accessが削除されました。",
              delivery: delivery,
              sync_status: "repository_removed"
            )
          elsif action == "added"
            sync_account_permissions!(
              account: account,
              permissions: permissions,
              delivery: delivery
            )
          end
          affected += 1
        end
      end
      affected
    end

    def sync_account_permissions!(account:, permissions:, delivery:)
      next_permissions = permissions.presence || account.granted_permissions
      if issues_write_granted?(next_permissions)
        update_account!(
          account: account,
          status: "connected",
          permissions: next_permissions,
          safe_error: nil,
          delivery: delivery,
          sync_status: "connected"
        )
      else
        update_account!(
          account: account,
          status: "error",
          permissions: next_permissions,
          safe_error: "GitHub AppのIssues write権限がありません。",
          delivery: delivery,
          sync_status: "permission_error"
        )
      end
    end

    def update_account!(account:, status:, permissions:, safe_error:, delivery:, sync_status:)
      account.update!(
        status: status,
        granted_permissions: permissions,
        last_error_safe: safe_error,
        last_sync_at: Time.current
      )

      AuditLog.record!(
        project: account.project,
        action: "github.webhook.installation_sync",
        target: account,
        summary: "GitHub installation webhookを同期しました。",
        metadata: {
          event: delivery.event,
          delivery_digest: delivery.delivery_digest,
          github_installation_id: account.github_installation_id,
          repository: account.github_repository,
          sync_status: sync_status,
          account_status: account.status,
          safe_error_code: safe_error.present? ? sync_status : nil
        }.compact
      )
    end

    def required_installation_id(payload)
      value = installation_id(payload)
      raise WebhookError.new(
        code: "github_webhook_installation_missing",
        message: "GitHub Webhook installation idが不足しています。",
        safe_detail: "GitHub Webhook installation idが不足しています。"
      ) if value.blank?

      value
    end

    def installation_id(payload)
      payload.dig("installation", "id").to_s.presence
    end

    def repositories_for_action(payload, action)
      key = action == "removed" ? "repositories_removed" : "repositories_added"
      Array(payload[key]).filter_map { |repository| repository_full_name(repository) }
    end

    def accounts_for_repository(installation_id:, repository:)
      owner, name = repository.split("/", 2)
      IntegrationAccount.where(
        provider: "github",
        github_installation_id: installation_id,
        repository_owner: owner,
        repository_name: name
      )
    end

    def primary_repository(payload)
      repository_full_name(payload["repository"]) ||
        repository_full_name(Array(payload["repositories_removed"]).first) ||
        repository_full_name(Array(payload["repositories_added"]).first)
    end

    def repository_full_name(repository)
      return if repository.blank?

      full_name = repository["full_name"].to_s.strip
      return full_name if full_name.present?

      owner = repository.dig("owner", "login").to_s.strip
      name = repository["name"].to_s.strip
      return if owner.blank? || name.blank?

      "#{owner}/#{name}"
    end

    def safe_permissions(raw_permissions)
      (raw_permissions || {}).to_h.each_with_object({}) do |(key, value), sanitized|
        normalized_key = key.to_s
        normalized_value = value.to_s
        next unless SAFE_PERMISSION_KEYS.include?(normalized_key)
        next unless normalized_value.match?(/\A[a-z_]+\z/)

        sanitized[normalized_key] = normalized_value
      end
    end

    def issues_write_granted?(permissions)
      permissions.to_h["issues"] == "write"
    end
  end
end
