module Operations
  class RetryRefailureRateQuery
    RECENT_WINDOW = 24.hours
    THRESHOLD = 0.1

    def self.not_measured(retry_count: 0, exclusion_reason: nil)
      exclusions = default_exclusions
      exclusions[exclusion_reason] = retry_count if exclusion_reason

      {
        measured: false,
        window_hours: (RECENT_WINDOW / 1.hour).to_i,
        retry_count: retry_count,
        denominator: 0,
        numerator: 0,
        rate: nil,
        threshold: THRESHOLD,
        exclusions: exclusions
      }
    end

    def self.default_exclusions
      {
        missing_product_job_id: 0,
        missing_solid_queue_job_id: 0,
        mapping_mismatch: 0,
        solid_queue_unavailable: 0
      }
    end

    def initialize(project:)
      @project = project
    end

    def call(checked_at: Time.current)
      retry_logs = retry_audit_logs(checked_at).to_a
      return self.class.not_measured(retry_count: 0) if retry_logs.empty?

      measurable_events = []
      exclusions = self.class.default_exclusions
      mappings_by_solid_queue_job_id = retry_mappings_by_solid_queue_job_id(retry_logs)

      retry_logs.each do |audit_log|
        event = retry_event(audit_log)
        if event[:product_job_id].blank?
          exclusions[:missing_product_job_id] += 1
          next
        end
        if event[:solid_queue_job_id].blank?
          exclusions[:missing_solid_queue_job_id] += 1
          next
        end

        mapping = mappings_by_solid_queue_job_id[event[:solid_queue_job_id]]
        unless mapping && mapping.job_id == event[:product_job_id]
          exclusions[:mapping_mismatch] += 1
          next
        end

        measurable_events << event
      end

      return not_measured_with_exclusions(retry_logs.size, exclusions) if measurable_events.empty?

      refailed_count = refailed_retry_count(measurable_events)
      measured_result(
        retry_count: retry_logs.size,
        measurable_retry_count: measurable_events.size,
        refailed_retry_count: refailed_count,
        exclusions: exclusions
      )
    rescue NameError, ActiveRecord::ActiveRecordError
      self.class.not_measured(retry_count: retry_audit_logs(checked_at).count, exclusion_reason: :solid_queue_unavailable)
    end

    private

    attr_reader :project

    def retry_audit_logs(checked_at)
      project.audit_logs
        .where(action: "operations.failed_job_retried")
        .where("created_at >= ?", checked_at - RECENT_WINDOW)
        .order(created_at: :asc)
    end

    def retry_mappings_by_solid_queue_job_id(retry_logs)
      solid_queue_job_ids = retry_logs.filter_map { |audit_log| retry_event(audit_log)[:solid_queue_job_id] }.uniq
      return {} if solid_queue_job_ids.empty?

      JobQueueMapping
        .where(project: project, provider: "solid_queue", solid_queue_job_id: solid_queue_job_ids)
        .index_by(&:solid_queue_job_id)
    end

    def retry_event(audit_log)
      metadata = audit_log.metadata || {}
      {
        audit_log_id: audit_log.id,
        retried_at: audit_log.created_at,
        product_job_id: metadata["product_job_id"],
        solid_queue_job_id: Integer(metadata["job_id"], exception: false)
      }
    end

    def refailed_retry_count(measurable_events)
      failed_rows_by_job_id = failed_execution_rows(measurable_events.map { |event| event.fetch(:solid_queue_job_id) }.uniq)
        .group_by { |job_id, _failed_at| job_id }

      measurable_events.count do |event|
        failed_rows_by_job_id.fetch(event.fetch(:solid_queue_job_id), []).any? do |_job_id, failed_at|
          failed_at > event.fetch(:retried_at)
        end
      end
    end

    def failed_execution_rows(solid_queue_job_ids)
      return [] if solid_queue_job_ids.empty?

      SolidQueue::FailedExecution.where(job_id: solid_queue_job_ids).pluck(:job_id, :created_at)
    end

    def not_measured_with_exclusions(retry_count, exclusions)
      self.class.not_measured(retry_count: retry_count).merge(exclusions: exclusions)
    end

    def measured_result(retry_count:, measurable_retry_count:, refailed_retry_count:, exclusions:)
      {
        measured: true,
        window_hours: (RECENT_WINDOW / 1.hour).to_i,
        retry_count: retry_count,
        denominator: measurable_retry_count,
        numerator: refailed_retry_count,
        rate: (refailed_retry_count.to_f / measurable_retry_count).round(4),
        threshold: THRESHOLD,
        exclusions: exclusions
      }
    end
  end
end
