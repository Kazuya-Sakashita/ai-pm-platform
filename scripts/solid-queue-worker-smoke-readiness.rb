#!/usr/bin/env ruby
# frozen_string_literal: true

require "erb"
require "json"
require "optparse"
require "time"
require "yaml"

class SolidQueueWorkerSmokeReadiness
  EXPECTED_RECURRING_TASKS = {
    "cleanup_expired_github_connection_states" => {
      class_name: "GithubIntegration::ConnectionStateCleanupJob",
      queue_name: "default"
    },
    "enforce_conversation_import_retention" => {
      class_name: "ConversationImportRetentionJob",
      queue_name: "default"
    }
  }.freeze

  TABLE_MODELS = [
    "SolidQueue::Job",
    "SolidQueue::Process",
    "SolidQueue::FailedExecution",
    "SolidQueue::RecurringTask"
  ].freeze

  HEARTBEAT_STALE_AFTER_SECONDS = 60
  OLDEST_UNFINISHED_THRESHOLD_SECONDS = 300
  PRODUCTION_LIKE_ENVIRONMENTS = %w[staging production].freeze

  def initialize(env:, stdout:, stderr:)
    @env = env
    @stdout = stdout
    @stderr = stderr
  end

  def run(argv)
    options = parse_options(argv)
    payload = execute(options)
    stdout.puts(JSON.pretty_generate(payload))
    payload.fetch(:safe_failures).empty? ? 0 : 1
  rescue OptionParser::ParseError => e
    stderr.puts("引数が不正です: #{e.message}")
    stderr.puts(option_parser.to_s)
    2
  end

  private

  attr_reader :env, :stdout, :stderr

  def execute(options)
    checked_at = Time.now.utc
    environment_name = options.fetch(:environment_name)
    production_like = options.fetch(:production_like)
    payload = base_payload(checked_at, environment_name, production_like, options)

    unless rails_loaded?
      return with_next_actions(
        payload.merge(
          safe_failures: payload.fetch(:safe_failures) + ["rails_environment_not_loaded"]
        )
      )
    end

    payload[:rails_env] = Rails.env
    payload[:active_job_adapter] = active_job_adapter
    payload[:configured_queues] = configured_queues
    payload[:secret_presence] = secret_presence
    payload[:solid_queue_tables] = solid_queue_tables

    unless solid_queue_available?
      return with_next_actions(
        payload.merge(
          queue_health: queue_health_snapshot,
          safe_failures: payload.fetch(:safe_failures) + solid_queue_unavailable_failures(payload, options)
        )
      )
    end

    payload[:worker_heartbeat] = worker_heartbeat_snapshot(checked_at)
    payload[:recurring_tasks] = recurring_task_snapshot
    payload[:queue_latency] = queue_latency_snapshot(checked_at)
    payload[:failed_executions] = failed_execution_snapshot
    payload[:queue_health] = queue_health_snapshot
    payload[:safe_warnings] = payload.fetch(:safe_warnings) + warning_codes(payload)
    payload[:safe_failures] = payload.fetch(:safe_failures) + failure_codes(payload, options)
    with_next_actions(payload)
  rescue StandardError => e
    with_next_actions(
      base_payload(Time.now.utc, options.fetch(:environment_name), options.fetch(:production_like), options).merge(
        safe_failures: ["solid_queue_worker_smoke_unexpected_error"],
        safe_error_class: e.class.name
      )
    )
  end

  def base_payload(checked_at, environment_name, production_like, options)
    {
      checked_at: checked_at.iso8601,
      environment_name: environment_name,
      rails_env: nil,
      production_like: production_like,
      require_worker: options.fetch(:require_worker),
      expect_solid_queue: options.fetch(:expect_solid_queue),
      active_job_adapter: nil,
      configured_queues: [],
      secret_presence: {},
      solid_queue_tables: {},
      worker_heartbeat: {},
      recurring_tasks: {},
      queue_latency: {},
      failed_executions: {},
      queue_health: {},
      safe_warnings: [],
      safe_failures: [],
      next_actions: []
    }
  end

  def parse_options(argv)
    defaults = {
      environment_name: default_environment_name,
      require_worker: true,
      expect_solid_queue: true,
      production_like: nil
    }
    parsed_options.clear
    option_parser.parse!(argv)
    options = defaults.merge(parsed_options)
    options[:production_like] = production_like?(options.fetch(:environment_name)) if options[:production_like].nil?
    options
  end

  def option_parser
    @option_parser ||= OptionParser.new do |opts|
      opts.banner = "Usage: solid-queue-worker-smoke-readiness.rb [options]"
      opts.on("--smoke-environment NAME", "Evidence environment name, for example staging or production") do |value|
        parsed_options[:environment_name] = value
      end
      opts.on("--require-worker", "Fail when no recent worker heartbeat exists") do
        parsed_options[:require_worker] = true
      end
      opts.on("--no-require-worker", "Allow observation before worker startup") do
        parsed_options[:require_worker] = false
      end
      opts.on("--expect-solid-queue", "Fail unless ActiveJob adapter is solid_queue") do
        parsed_options[:expect_solid_queue] = true
      end
      opts.on("--no-expect-solid-queue", "Do not fail on non Solid Queue adapter") do
        parsed_options[:expect_solid_queue] = false
      end
      opts.on("--production-like", "Treat the environment as staging/production") do
        parsed_options[:production_like] = true
      end
      opts.on("--no-production-like", "Treat the environment as local/non-production") do
        parsed_options[:production_like] = false
      end
    end
  end

  def parsed_options
    @parsed_options ||= {}
  end

  def default_environment_name
    return env["SMOKE_ENVIRONMENT"] if present?(env["SMOKE_ENVIRONMENT"])
    return Rails.env if rails_loaded?

    env.fetch("RAILS_ENV", "unknown")
  end

  def production_like?(environment_name)
    PRODUCTION_LIKE_ENVIRONMENTS.include?(environment_name.to_s)
  end

  def rails_loaded?
    defined?(Rails) && defined?(ActiveRecord::Base)
  end

  def active_job_adapter
    adapter = ActiveJob::Base.queue_adapter
    adapter.respond_to?(:name) ? adapter.name.to_s : adapter.class.name
  rescue StandardError
    Rails.application.config.active_job.queue_adapter.to_s
  end

  def secret_presence
    {
      database_url: present?(env["DATABASE_URL"]),
      queue_database_url: present?(env["QUEUE_DATABASE_URL"]),
      rails_master_key: present?(env["RAILS_MASTER_KEY"]),
      active_record_encryption_primary_key: present?(env["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]),
      active_record_encryption_deterministic_key: present?(env["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]),
      active_record_encryption_key_derivation_salt: present?(env["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"])
    }
  end

  def solid_queue_tables
    TABLE_MODELS.to_h do |model_name|
      [model_name, table_available?(model_name)]
    end
  end

  def solid_queue_available?
    solid_queue_tables.values.all?
  end

  def table_available?(model_name)
    model = model_name.constantize
    model.connection.data_source_exists?(model.table_name)
  rescue NameError, ActiveRecord::ActiveRecordError
    false
  end

  def solid_queue_unavailable_failures(payload, options)
    failures = ["solid_queue_tables_unavailable"]
    failures << "active_job_adapter_not_solid_queue" if options.fetch(:expect_solid_queue) && !solid_queue_adapter?(payload)
    failures.concat(production_secret_failures(payload)) if payload.fetch(:production_like)
    failures
  end

  def worker_heartbeat_snapshot(checked_at)
    processes = SolidQueue::Process.order(last_heartbeat_at: :desc).limit(20).to_a
    newest_heartbeat_at = processes.map(&:last_heartbeat_at).compact.max
    stale_count = processes.count do |process|
      !present?(process.last_heartbeat_at) || (checked_at - process.last_heartbeat_at) > HEARTBEAT_STALE_AFTER_SECONDS
    end

    {
      process_count: processes.size,
      stale_process_count: stale_count,
      newest_heartbeat_at: newest_heartbeat_at&.utc&.iso8601,
      kinds: processes.map(&:kind).compact.uniq.sort
    }
  end

  def recurring_task_snapshot
    config_tasks = recurring_config_tasks
    loaded_tasks = SolidQueue::RecurringTask.where(key: EXPECTED_RECURRING_TASKS.keys).order(:key).to_a
    loaded_by_key = loaded_tasks.index_by(&:key)

    EXPECTED_RECURRING_TASKS.to_h do |key, expectation|
      configured = config_tasks[key] || {}
      loaded = loaded_by_key[key]
      [
        key,
        {
          configured: present?(configured),
          configured_class_name: configured[:class_name],
          configured_queue_name: configured[:queue_name],
          configured_schedule: configured[:schedule],
          loaded: !loaded.nil?,
          loaded_class_name: loaded&.class_name,
          loaded_queue_name: loaded&.queue_name,
          loaded_schedule: loaded&.schedule,
          expected_class_name: expectation.fetch(:class_name),
          expected_queue_name: expectation.fetch(:queue_name)
        }.compact
      ]
    end
  end

  def recurring_config_tasks
    path = Rails.root.join("config/recurring.yml")
    raw = YAML.safe_load(ERB.new(path.read).result, aliases: true) || {}
    config = raw.fetch(Rails.env, raw.fetch("production", {}))
    config.transform_values do |task|
      {
        class_name: task["class"],
        queue_name: task["queue"],
        schedule: task["schedule"]
      }.compact
    end
  rescue Errno::ENOENT, Psych::Exception, KeyError
    {}
  end

  def queue_latency_snapshot(checked_at)
    unfinished_scope = SolidQueue::Job.where(finished_at: nil)
    oldest_by_queue = unfinished_scope.group(:queue_name).minimum(:created_at)
    counts_by_queue = unfinished_scope.group(:queue_name).count
    queues = (configured_queues + counts_by_queue.keys).uniq

    {
      queues: queues.map do |queue_name|
        oldest_at = oldest_by_queue[queue_name]
        age_seconds = oldest_at ? (checked_at - oldest_at).to_i : nil
        {
          queue_name: queue_name,
          unfinished_count: counts_by_queue.fetch(queue_name, 0),
          oldest_unfinished_at: oldest_at&.utc&.iso8601,
          oldest_unfinished_age_seconds: age_seconds
        }.compact
      end,
      threshold_seconds: OLDEST_UNFINISHED_THRESHOLD_SECONDS
    }
  end

  def failed_execution_snapshot
    {
      count: SolidQueue::FailedExecution.count,
      latest_failed_at: SolidQueue::FailedExecution.maximum(:created_at)&.utc&.iso8601
    }.compact
  end

  def queue_health_snapshot
    return {} unless defined?(Operations::QueueHealthQuery)

    data = Operations::QueueHealthQuery.new.call
    {
      status: data[:status],
      checked_at: data[:checked_at],
      worker_count: Array(data[:workers]).size,
      stale_worker_count: Array(data[:workers]).count { |worker| worker[:stale] },
      failed_execution_count: data.dig(:failed_executions, :count),
      recurring_task_count: Array(data[:recurring_tasks]).size,
      failed_job_release_gate_status: data.dig(:failed_job_release_gate, :status),
      warnings: Array(data[:warnings])
    }.compact
  rescue StandardError => e
    { status: "unavailable", safe_error_class: e.class.name }
  end

  def configured_queues
    path = Rails.root.join("config/queue.yml")
    raw = YAML.safe_load(ERB.new(path.read).result, aliases: true) || {}
    workers = raw.fetch(Rails.env, raw.fetch("production", {})).fetch("workers", [])
    workers.flat_map { |worker| worker.fetch("queues", []) }.uniq
  rescue Errno::ENOENT, Psych::Exception, KeyError
    []
  end

  def warning_codes(payload)
    warnings = []
    warnings << "failed_executions_present" if payload.dig(:failed_executions, :count).to_i.positive?
    warnings << "queue_health_degraded" if payload.dig(:queue_health, :status) == "degraded"
    warnings << "queue_health_unavailable" if payload.dig(:queue_health, :status) == "unavailable"
    warnings.concat(queue_latency_warnings(payload))
    warnings.uniq
  end

  def failure_codes(payload, options)
    failures = []
    failures << "active_job_adapter_not_solid_queue" if options.fetch(:expect_solid_queue) && !solid_queue_adapter?(payload)
    failures << "worker_heartbeat_missing" if options.fetch(:require_worker) && payload.dig(:worker_heartbeat, :process_count).to_i.zero?
    failures << "worker_heartbeat_stale" if options.fetch(:require_worker) && payload.dig(:worker_heartbeat, :stale_process_count).to_i.positive?
    failures.concat(recurring_task_failures(payload))
    failures.concat(production_secret_failures(payload)) if payload.fetch(:production_like)
    failures.uniq
  end

  def solid_queue_adapter?(payload)
    payload.fetch(:active_job_adapter).to_s.include?("SolidQueue") ||
      payload.fetch(:active_job_adapter).to_s == "solid_queue"
  end

  def recurring_task_failures(payload)
    tasks = payload.fetch(:recurring_tasks)
    tasks.flat_map do |key, task|
      failures = []
      failures << "#{key}_recurring_task_not_configured" unless task[:configured]
      failures << "#{key}_recurring_task_not_loaded" unless task[:loaded]
      failures << "#{key}_recurring_task_class_mismatch" if task[:loaded] && task[:loaded_class_name] != task[:expected_class_name]
      failures << "#{key}_recurring_task_queue_mismatch" if task[:loaded] && task[:loaded_queue_name] != task[:expected_queue_name]
      failures
    end
  end

  def production_secret_failures(payload)
    presence = payload.fetch(:secret_presence)
    failures = []
    failures << "queue_database_url_missing" unless presence[:queue_database_url]
    failures << "active_record_encryption_primary_key_missing" unless presence[:active_record_encryption_primary_key]
    failures << "active_record_encryption_deterministic_key_missing" unless presence[:active_record_encryption_deterministic_key]
    failures << "active_record_encryption_key_derivation_salt_missing" unless presence[:active_record_encryption_key_derivation_salt]
    failures
  end

  def queue_latency_warnings(payload)
    queues = Array(payload.dig(:queue_latency, :queues))
    queues.filter_map do |queue|
      age = queue[:oldest_unfinished_age_seconds]
      next unless age && age > OLDEST_UNFINISHED_THRESHOLD_SECONDS

      "#{queue[:queue_name]}_queue_oldest_unfinished_exceeded"
    end
  end

  def with_next_actions(payload)
    failures = Array(payload[:safe_failures]).uniq
    payload.merge(
      safe_failures: failures,
      next_actions: next_actions_for(failures)
    )
  end

  def next_actions_for(failures)
    actions = failures.flat_map do |failure|
      case failure
      when "rails_environment_not_loaded"
        ["backendディレクトリからbundle exec ruby bin/rails runner ../scripts/solid-queue-worker-smoke-readiness.rbで実行する。"]
      when "solid_queue_tables_unavailable"
        ["staging/production-equivalent環境でqueue_schema適用済みのQUEUE_DATABASE_URLを設定して再実行する。"]
      when "active_job_adapter_not_solid_queue"
        ["production-like環境のActiveJob adapterをsolid_queueへ設定する。"]
      when "worker_heartbeat_missing", "worker_heartbeat_stale"
        ["worker processを起動または再起動し、60秒以内のheartbeatを確認する。"]
      when "queue_database_url_missing"
        ["QUEUE_DATABASE_URLをsecret storeへ設定する。"]
      when "active_record_encryption_primary_key_missing",
           "active_record_encryption_deterministic_key_missing",
           "active_record_encryption_key_derivation_salt_missing"
        ["Active Record Encryption keyをsecret storeへ設定する。"]
      when /_recurring_task_not_configured\z/
        ["backend/config/recurring.ymlで対象recurring taskを設定する。"]
      when /_recurring_task_not_loaded\z/
        ["worker/scheduler起動後にrecurring taskがloadedになることを確認する。"]
      when /_recurring_task_(class|queue)_mismatch\z/
        ["recurring taskのclass/queue設定をrunbookの期待値へ合わせる。"]
      when "solid_queue_worker_smoke_unexpected_error"
        ["safe_error_classを確認し、secret値やraw argumentsを出さずに起動ログを調査する。"]
      else
        ["safe failure #{failure} をrunbookに照らして確認する。"]
      end
    end
    actions.uniq
  end

  def present?(value)
    !value.nil? && !value.to_s.empty?
  end
end

if $PROGRAM_NAME == __FILE__
  exit SolidQueueWorkerSmokeReadiness.new(env: ENV, stdout: $stdout, stderr: $stderr).run(ARGV)
end
