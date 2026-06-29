class SensitiveContentScanner
  Finding = Struct.new(:type, :severity, keyword_init: true)
  Result = Struct.new(:status, :findings, keyword_init: true) do
    def blocked?
      status == "blocked"
    end

    def finding_types
      findings.map(&:type).uniq
    end
  end

  SECRET_PATTERNS = [
    ["openai_api_key", /sk-[A-Za-z0-9_-]{20,}/],
    ["github_token", /gh[pousr]_[A-Za-z0-9_]{20,}/],
    ["private_key", /-----BEGIN [A-Z ]*PRIVATE KEY-----/],
    ["authorization_header", /authorization:\s*bearer\s+\S+/i],
    ["password", /\bpassword\s*[:=]\s*\S+/i],
    ["database_url", /postgres(?:ql)?:\/\/\S+/i]
  ].freeze

  def self.scan(text)
    new(text).scan
  end

  def initialize(text)
    @text = text.to_s
  end

  def scan
    findings = SECRET_PATTERNS.filter_map do |type, pattern|
      Finding.new(type: type, severity: "blocked") if text.match?(pattern)
    end

    Result.new(
      status: findings.empty? ? "clear" : "blocked",
      findings: findings
    )
  end

  private

  attr_reader :text
end
