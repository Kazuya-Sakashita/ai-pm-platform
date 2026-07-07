module Operations
  class FailedJobProjectResolver
    UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

    Result = Struct.new(:status, :product_job, :solid_queue_job_id, :active_job_id, :product_job_mapping_source, keyword_init: true) do
      def verified?
        status == "verified" && product_job.present?
      end

      def verified_for?(project)
        verified? && product_job.project_id.to_s == project.id.to_s
      end

      def status_for(project)
        return "verified" if verified_for?(project)
        return "project_mismatch" if verified?

        status
      end

      def safe_metadata(project:)
        metadata = {
          project_boundary_status: status_for(project),
          requested_project_id: project.id,
          solid_queue_job_id: solid_queue_job_id,
          active_job_id: active_job_id,
          product_job_mapping_source: product_job_mapping_source
        }.compact

        return metadata unless verified_for?(project)

        metadata.merge(
          project_boundary_status: status,
          product_job_id: product_job&.id,
          product_job_project_id: product_job&.project_id
        ).compact
      end
    end

    def initialize(solid_queue_job)
      @solid_queue_job = solid_queue_job
    end

    def call
      return result("solid_queue_job_missing") unless solid_queue_job

      explicit_mapping = explicit_product_job_mapping
      return result("verified", product_job: explicit_mapping.product_job, product_job_mapping_source: "explicit") if explicit_mapping

      product_jobs = candidate_product_jobs
      return result("product_job_unresolved") if product_jobs.empty?
      return result("product_job_ambiguous", product_job_mapping_source: "arguments") if product_jobs.size > 1

      result("verified", product_job: product_jobs.first, product_job_mapping_source: "arguments")
    rescue ActiveRecord::ActiveRecordError
      result("product_job_lookup_failed")
    end

    private

    attr_reader :solid_queue_job

    def explicit_product_job_mapping
      return nil unless solid_queue_job&.id

      JobQueueMapping.includes(:product_job).find_by(provider: "solid_queue", solid_queue_job_id: solid_queue_job.id)
    end

    def candidate_product_jobs
      ids = candidate_product_job_ids
      return [] if ids.empty?

      Job.where(id: ids).to_a
    end

    def candidate_product_job_ids
      collect_strings(solid_queue_job.arguments).select { |value| value.match?(UUID_PATTERN) }.uniq
    end

    def collect_strings(value)
      case value
      when String
        [ value ]
      when Array
        value.flat_map { |item| collect_strings(item) }
      when Hash
        value.values.flat_map { |item| collect_strings(item) }
      else
        []
      end
    end

    def result(status, product_job: nil, product_job_mapping_source: nil)
      Result.new(
        status: status,
        product_job: product_job,
        solid_queue_job_id: solid_queue_job&.id,
        active_job_id: solid_queue_job&.active_job_id,
        product_job_mapping_source: product_job_mapping_source
      )
    end
  end
end
