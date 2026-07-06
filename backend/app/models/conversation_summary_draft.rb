class ConversationSummaryDraft < ApplicationRecord
  STATUSES = %w[draft needs_revision approved rejected stale].freeze
  EDITABLE_STATUSES = %w[draft needs_revision].freeze
  ANONYMIZED_SUMMARY = "削除済み".freeze
  STORED_SUMMARY_PLACEHOLDER = "暗号化済み".freeze
  PROTECTED_PAYLOAD_DEFAULTS = {
    summary: nil,
    decisions: [],
    open_questions: [],
    action_items: [],
    issue_candidates: [],
    requirement_candidates: [],
    risks: [],
    participants: [],
    source_quotes: [],
    validation_errors: []
  }.freeze
  PROTECTED_ARRAY_FIELDS = (PROTECTED_PAYLOAD_DEFAULTS.keys - [:summary]).freeze

  belongs_to :conversation_import

  encrypts :protected_payload

  validates :status, inclusion: { in: STATUSES }
  validates :summary, presence: true
  validates :confidence, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  before_validation :set_defaults
  before_validation :prepare_protected_payload_for_storage

  PROTECTED_PAYLOAD_DEFAULTS.each_key do |field|
    define_method(field) do
      protected_payload_value(field)
    end

    define_method("#{field}=") do |value|
      write_protected_payload_value(field, value)
    end
  end

  def anonymize!(anonymized_at: Time.current)
    update!(
      status: "rejected",
      summary: ANONYMIZED_SUMMARY,
      decisions: [],
      open_questions: [],
      action_items: [],
      issue_candidates: [],
      requirement_candidates: [],
      risks: [],
      participants: [],
      source_quotes: [],
      confidence: 0.0,
      validation_errors: [],
      retention_expires_at: retention_expires_at || anonymized_at
    )
  end

  def editable?
    EDITABLE_STATUSES.include?(status)
  end

  def api_json
    {
      id: id,
      conversation_import_id: conversation_import_id,
      status: status,
      summary: summary,
      decisions: decisions,
      open_questions: open_questions,
      action_items: action_items,
      issue_candidates: issue_candidates,
      requirement_candidates: requirement_candidates,
      risks: risks,
      participants: participants,
      source_quotes: source_quotes,
      confidence: confidence&.to_f,
      generated_by_model: model,
      retention_expires_at: iso_time(retention_expires_at),
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }.compact
  end

  private

  def set_defaults
    self.status ||= "draft"
    self.provider ||= "deterministic"
    self.generated_at ||= Time.current
    self.decisions ||= []
    self.open_questions ||= []
    self.action_items ||= []
    self.issue_candidates ||= []
    self.requirement_candidates ||= []
    self.risks ||= []
    self.participants ||= []
    self.source_quotes ||= []
    self.validation_errors ||= []
    self.retention_expires_at ||= conversation_import&.retention_expires_at || Time.current + ConversationImport::CONTENT_RETENTION_WINDOW
  end

  def protected_payload_hash
    value = read_attribute(:protected_payload)
    return @protected_payload_hash if defined?(@protected_payload_source) && @protected_payload_source == value && @protected_payload_hash

    @protected_payload_source = value
    value = JSON.generate(value) if value.is_a?(Hash)
    parsed = value.present? ? JSON.parse(value) : {}
    @protected_payload_hash = parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError
    @protected_payload_hash = {}
  end

  def protected_payload_value(field)
    key = field.to_s
    if protected_payload_hash.key?(key)
      normalize_protected_payload_value(field, protected_payload_hash.fetch(key))
    else
      normalize_protected_payload_value(field, read_attribute(field))
    end
  end

  def write_protected_payload_value(field, value)
    key = field.to_s
    @protected_payload_hash = protected_payload_hash.merge(key => normalize_protected_payload_value(field, value))
    self.protected_payload = JSON.generate(@protected_payload_hash)
    @protected_payload_hash.fetch(key)
  end

  def normalize_protected_payload_value(field, value)
    return value.to_s if field == :summary && value.present?
    return nil if field == :summary

    Array(value).map { |entry| entry.respond_to?(:as_json) ? entry.as_json : entry }
  end

  def prepare_protected_payload_for_storage
    payload = {}
    PROTECTED_PAYLOAD_DEFAULTS.each_key do |field|
      payload[field.to_s] = protected_payload_value(field)
    end
    @protected_payload_hash = payload
    self.protected_payload = JSON.generate(payload)

    write_attribute(:summary, STORED_SUMMARY_PLACEHOLDER)
    PROTECTED_ARRAY_FIELDS.each do |field|
      write_attribute(field, [])
    end
  end
end
