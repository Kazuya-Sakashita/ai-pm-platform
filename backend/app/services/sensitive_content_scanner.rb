class SensitiveContentScanner
  Finding = Struct.new(:type, :category, :severity, :action, :location_hint, :message, :suggested_replacement, keyword_init: true)
  Rule = Struct.new(:type, :category, :pattern, :location_hint, :message, :suggested_replacement, keyword_init: true)
  Result = Struct.new(:status, :findings, keyword_init: true) do
    def blocked?
      status == "blocked"
    end

    def finding_types
      findings.map(&:type).uniq
    end

    def finding_categories
      findings.map(&:category).uniq
    end
  end

  RULES = [
    Rule.new(
      type: "email_address",
      category: "personal_data",
      pattern: /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i,
      location_hint: "メールアドレス",
      message: "メールアドレスの可能性があります。AI整理前に個人を特定できない表現へ置換してください。",
      suggested_replacement: "[EMAIL_REDACTED]"
    ),
    Rule.new(
      type: "phone_number",
      category: "personal_data",
      pattern: /(?:\+81[-\s]?)?0\d{1,4}[-\s]?\d{1,4}[-\s]?\d{3,4}/,
      location_hint: "電話番号",
      message: "電話番号の可能性があります。AI整理前に連絡先を伏字化してください。",
      suggested_replacement: "[PHONE_REDACTED]"
    ),
    Rule.new(
      type: "japanese_address",
      category: "personal_data",
      pattern: /(?:〒\s?\d{3}-\d{4}|(?:北海道|東京都|京都府|大阪府|.{2,3}県).{0,20}(?:市|区|町|村).{0,30}\d{1,4}(?:-\d{1,4}){0,2})/,
      location_hint: "住所",
      message: "住所または郵便番号の可能性があります。AI整理前に所在地を伏字化してください。",
      suggested_replacement: "[ADDRESS_REDACTED]"
    ),
    Rule.new(
      type: "url_token",
      category: "credential",
      pattern: %r{https?://\S*(?:[?&](?:access[_-]?token|token|api[_-]?key|secret|client_secret|code)=)[^\s]+}i,
      location_hint: "URLクエリ",
      message: "URL内にtokenやsecretの可能性があります。AI整理前に認証情報を削除してください。",
      suggested_replacement: "[URL_WITH_TOKEN_REDACTED]"
    ),
    Rule.new(
      type: "openai_api_key",
      category: "credential",
      pattern: /sk-[A-Za-z0-9_-]{20,}/,
      location_hint: "APIキー",
      message: "API keyの可能性があります。AI整理前に認証情報を削除してください。",
      suggested_replacement: "[API_KEY_REDACTED]"
    ),
    Rule.new(
      type: "github_token",
      category: "credential",
      pattern: /gh[pousr]_[A-Za-z0-9_]{20,}/,
      location_hint: "GitHub token",
      message: "GitHub tokenの可能性があります。AI整理前に認証情報を削除してください。",
      suggested_replacement: "[TOKEN_REDACTED]"
    ),
    Rule.new(
      type: "generic_api_key",
      category: "credential",
      pattern: /\b(?:api[_-]?key|secret[_-]?key|access[_-]?token)\s*[:=]\s*["']?[A-Za-z0-9_.-]{16,}/i,
      location_hint: "APIキー",
      message: "API keyまたはaccess tokenの可能性があります。AI整理前に認証情報を削除してください。",
      suggested_replacement: "[API_KEY_REDACTED]"
    ),
    Rule.new(
      type: "private_key",
      category: "secret",
      pattern: /-----BEGIN [A-Z ]*PRIVATE KEY-----/,
      location_hint: "秘密鍵",
      message: "秘密鍵の可能性があります。AI整理前に秘密情報を削除してください。",
      suggested_replacement: "[PRIVATE_KEY_REDACTED]"
    ),
    Rule.new(
      type: "authorization_header",
      category: "credential",
      pattern: /authorization:\s*bearer\s+\S+/i,
      location_hint: "Authorization header",
      message: "Authorization headerの可能性があります。AI整理前に認証情報を削除してください。",
      suggested_replacement: "[AUTHORIZATION_REDACTED]"
    ),
    Rule.new(
      type: "password",
      category: "credential",
      pattern: /\bpassword\s*[:=]\s*\S+/i,
      location_hint: "パスワード",
      message: "パスワードの可能性があります。AI整理前に認証情報を削除してください。",
      suggested_replacement: "[PASSWORD_REDACTED]"
    ),
    Rule.new(
      type: "database_url",
      category: "secret",
      pattern: /postgres(?:ql)?:\/\/\S+/i,
      location_hint: "Database URL",
      message: "Database URLの可能性があります。AI整理前に接続情報を削除してください。",
      suggested_replacement: "[DATABASE_URL_REDACTED]"
    ),
    Rule.new(
      type: "financial_context",
      category: "financial",
      pattern: /(?:口座番号|銀行口座|振込先|支払先|クレジットカード|カード番号|請求書)/,
      location_hint: "金融情報",
      message: "金融または支払い情報の可能性があります。AI整理前に必要最小限の表現へ置換してください。",
      suggested_replacement: "[FINANCIAL_INFO_REDACTED]"
    ),
    Rule.new(
      type: "legal_context",
      category: "legal",
      pattern: /(?:NDA|秘密保持契約|契約書|個別契約|業務委託契約|反社条項|損害賠償|法務確認)/i,
      location_hint: "法務情報",
      message: "契約または法務情報の可能性があります。AI整理前に共有可能な範囲へ要約または伏字化してください。",
      suggested_replacement: "[LEGAL_INFO_REDACTED]"
    )
  ].freeze

  def self.scan(text)
    new(text).scan
  end

  def initialize(text)
    @text = text.to_s
  end

  def scan
    findings = RULES.filter_map do |rule|
      next unless text.match?(rule.pattern)

      Finding.new(
        type: rule.type,
        category: rule.category,
        severity: "high",
        action: "blocked",
        location_hint: rule.location_hint,
        message: rule.message,
        suggested_replacement: rule.suggested_replacement
      )
    end

    Result.new(
      status: findings.empty? ? "clear" : "blocked",
      findings: findings
    )
  end

  private

  attr_reader :text
end
