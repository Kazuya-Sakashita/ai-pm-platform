require "erb"
require "yaml"

module Operations
  class QueueHealthQuery
    HEARTBEAT_STALE_AFTER_SECONDS = 60
    OLDEST_UNFINISHED_THRESHOLD_SECONDS = 300
    RECENT_FAILURE_WINDOW = 24.hours
    WORKER_LIMIT = 20
    RECURRING_TASK_LIMIT = 20

    SOLID_QUEUE_MODELS = [
      "SolidQueue::Job",
      "SolidQueue::Process",
      "SolidQueue::FailedExecution",
      "SolidQueue::RecurringTask"
    ].freeze

    def call
      checked_at = Time.current
      warnings = []
      data = base_data(checked_at, warnings)
      data[:product_jobs] = product_jobs_summary(checked_at)

      unless solid_queue_available?
        warnings << "Solid Queue tableを確認できません。queue schema setupを確認してください。"
        data[:status] = "unavailable"
        return data
      end

      data[:workers] = worker_summaries(checked_at, warnings)
      data[:queues] = queue_summaries(checked_at, warnings)
      data[:failed_executions] = failed_execution_summary(warnings)
      data[:recurring_tasks] = recurring_task_summaries(warnings)

      recent_failed_count = data.dig(:product_jobs, :recent_failed_count).to_i
      warnings << "Product jobsに直近24時間の失敗が#{recent_failed_count}件あります。" if recent_failed_count.positive?

      data[:status] = warnings.empty? ? "healthy" : "degraded"
      data
    rescue ActiveRecord::ActiveRecordError
      unavailable_data(checked_at || Time.current)
    end

    private

    def base_data(checked_at, warnings)
      {
        status: "healthy",
        checked_at: iso_time(checked_at),
        heartbeat_stale_after_seconds: HEARTBEAT_STALE_AFTER_SECONDS,
        oldest_unfinished_threshold_seconds: OLDEST_UNFINISHED_THRESHOLD_SECONDS,
        workers: [],
        queues: configured_queue_names.map { |queue_name| queue_summary(queue_name, 0, nil, nil) },
        failed_executions: { count: 0 },
        recurring_tasks: [],
        product_jobs: { by_status: [], recent_failed_count: 0 },
        warnings: warnings
      }
    end

    def unavailable_data(checked_at)
      warnings = [ "Solid Queue healthを取得できません。queue database接続を確認してください。" ]
      data = base_data(checked_at, warnings)
      data[:product_jobs] = product_jobs_summary(checked_at)
      data[:status] = "unavailable"
      data
    end

    def solid_queue_available?
      solid_queue_models.all? do |model|
        model.connection.data_source_exists?(model.table_name)
      end
    rescue NameError, ActiveRecord::ActiveRecordError
      false
    end

    def solid_queue_models
      SOLID_QUEUE_MODELS.map(&:constantize)
    end

    def worker_summaries(checked_at, warnings)
      workers = SolidQueue::Process.order(last_heartbeat_at: :desc).limit(WORKER_LIMIT).map do |process|
        heartbeat_age = checked_at - process.last_heartbeat_at
        stale = heartbeat_age > HEARTBEAT_STALE_AFTER_SECONDS
        {
          kind: process.kind,
          name: process.name,
          hostname: process.hostname,
          last_heartbeat_at: iso_time(process.last_heartbeat_at),
          stale: stale
        }.compact
      end

      if workers.empty?
        warnings << "Solid Queue worker heartbeatが確認できません。"
      elsif workers.any? { |worker| worker[:stale] }
        warnings << "stale workerがあります。"
      end

      workers
    end

    def queue_summaries(checked_at, warnings)
      unfinished_scope = SolidQueue::Job.where(finished_at: nil)
      unfinished_counts = unfinished_scope.group(:queue_name).count
      oldest_by_queue = unfinished_scope.group(:queue_name).minimum(:created_at)
      queue_names = (configured_queue_names + unfinished_counts.keys).uniq

      queue_names.map do |queue_name|
        oldest_at = oldest_by_queue[queue_name]
        age_seconds = oldest_at ? (checked_at - oldest_at).to_i : nil
        if age_seconds && age_seconds > OLDEST_UNFINISHED_THRESHOLD_SECONDS
          warnings << "#{queue_name} queueに#{OLDEST_UNFINISHED_THRESHOLD_SECONDS}秒を超える未完了jobがあります。"
        end

        queue_summary(queue_name, unfinished_counts.fetch(queue_name, 0), oldest_at, age_seconds)
      end
    end

    def queue_summary(queue_name, unfinished_count, oldest_at, age_seconds)
      {
        queue_name: queue_name,
        unfinished_count: unfinished_count,
        oldest_unfinished_at: iso_time(oldest_at),
        oldest_unfinished_age_seconds: age_seconds
      }.compact
    end

    def failed_execution_summary(warnings)
      count = SolidQueue::FailedExecution.count
      latest_failed_at = SolidQueue::FailedExecution.maximum(:created_at)
      warnings << "failed executionが#{count}件あります。" if count.positive?

      {
        count: count,
        latest_failed_at: iso_time(latest_failed_at)
      }.compact
    end

    def recurring_task_summaries(warnings)
      tasks = SolidQueue::RecurringTask.order(:key).limit(RECURRING_TASK_LIMIT).map do |task|
        {
          key: task.key,
          class_name: task.class_name,
          queue_name: task.queue_name,
          schedule: task.schedule
        }.compact
      end

      cleanup_loaded = tasks.any? { |task| task[:key] == "cleanup_expired_github_connection_states" }
      warnings << "cleanup_expired_github_connection_states recurring taskが未ロードです。" unless cleanup_loaded

      tasks
    end

    def product_jobs_summary(checked_at)
      counts = Job.group(:status).count
      {
        by_status: Job::STATUSES.map do |status|
          { status: status, count: counts.fetch(status, 0) }
        end,
        recent_failed_count: Job.where(status: "failed").where("updated_at >= ?", checked_at - RECENT_FAILURE_WINDOW).count
      }
    end

    def configured_queue_names
      config = YAML.safe_load(
        ERB.new(Rails.root.join("config/queue.yml").read).result,
        aliases: true
      )
      workers = config.fetch(Rails.env, config.fetch("production", {})).fetch("workers", [])
      workers.flat_map { |worker| worker.fetch("queues", []) }.uniq
    rescue KeyError, Psych::Exception
      []
    end

    def iso_time(value)
      value&.iso8601
    end
  end
end
