class ConversationImport < ApplicationRecord
  SOURCE_TYPES = %w[discord_dm_paste].freeze
  STATUSES = %w[draft blocked ready_for_ai summarizing summary_draft approved rejected archived].freeze
  RAW_TEXT_RETENTION_WINDOW = 30.days
  CONTENT_RETENTION_WINDOW = 180.days
  RAW_TEXT_PURGED_PLACEHOLDER = "保持期限によりDM原文は削除済みです。".freeze
  ANONYMIZED_TITLE = "削除済みDMインポート".freeze
  ANONYMIZED_TEXT = "削除済み".freeze

  belongs_to :project
  has_many :conversation_summary_drafts, dependent: :destroy

  encrypts :raw_text
  encrypts :redacted_text

  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :title, presence: true, length: { maximum: 160 }
  validates :raw_text, presence: true, length: { maximum: 30_000 }
  validates :redacted_text, length: { maximum: 30_000 }, allow_blank: true
  validates :consent_statement_version, presence: true, length: { maximum: 64 }
  validates :consent_confirmed, inclusion: { in: [true, false] }

  before_validation :set_defaults

  def latest_summary_draft
    conversation_summary_drafts.order(created_at: :desc).first
  end

  def ai_source_text
    redacted_text.presence || raw_text
  end

  def purge_raw_text!(purged_at: Time.current)
    update!(raw_text: RAW_TEXT_PURGED_PLACEHOLDER, raw_text_purged_at: purged_at)
  end

  def anonymize!(anonymized_at: Time.current)
    transaction do
      conversation_summary_drafts.find_each { |draft| draft.anonymize!(anonymized_at: anonymized_at) }
      update!(
        title: ANONYMIZED_TITLE,
        raw_text: ANONYMIZED_TEXT,
        redacted_text: nil,
        participants: [],
        safety_flags: [],
        blocked_reasons: [],
        status: "archived",
        raw_text_purged_at: raw_text_purged_at || anonymized_at,
        anonymized_at: anonymized_at
      )
    end
  end

  def api_json(include_latest_summary: true)
    payload = {
      id: id,
      project_id: project_id,
      source_type: source_type,
      title: title,
      raw_text: raw_text,
      redacted_text: redacted_text,
      participants: participants,
      conversation_started_at: iso_time(conversation_started_at),
      conversation_ended_at: iso_time(conversation_ended_at),
      consent_confirmed: consent_confirmed,
      consent_confirmed_by: consent_confirmed_by,
      consent_confirmed_at: iso_time(consent_confirmed_at),
      consent_statement_version: consent_statement_version,
      status: status,
      safety_flags: safety_flags,
      blocked_reasons: blocked_reasons,
      raw_text_retention_expires_at: iso_time(raw_text_retention_expires_at),
      raw_text_purged_at: iso_time(raw_text_purged_at),
      retention_expires_at: iso_time(retention_expires_at),
      anonymized_at: iso_time(anonymized_at),
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }.compact

    if include_latest_summary
      draft = latest_summary_draft
      payload[:latest_summary_draft] = draft.api_json if draft
    end

    payload
  end

  private

  def set_defaults
    self.source_type ||= "discord_dm_paste"
    self.status ||= "draft"
    self.participants ||= []
    self.safety_flags ||= []
    self.blocked_reasons ||= []
    self.consent_confirmed = false if consent_confirmed.nil?
    self.consent_confirmed_at ||= Time.current if consent_confirmed?
    self.raw_text_retention_expires_at ||= Time.current + RAW_TEXT_RETENTION_WINDOW
    self.retention_expires_at ||= Time.current + CONTENT_RETENTION_WINDOW
  end
end
