require "json"
require "net/http"
require "uri"

module GithubIssuePublish
  class HttpClient
    Response = Struct.new(:status, :body, :headers, keyword_init: true) do
      def success?
        status >= 200 && status < 300
      end

      def json
        JSON.parse(body.presence || "{}")
      end
    end

    def initialize(api_base_url: "https://api.github.com", open_timeout: 10, read_timeout: 30)
      @api_base_url = api_base_url
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def post_json(path:, headers:, body: nil)
      request_json(Net::HTTP::Post, path: path, headers: headers, body: body)
    end

    def get_json(path:, headers:)
      request_json(Net::HTTP::Get, path: path, headers: headers)
    end

    private

    attr_reader :api_base_url, :open_timeout, :read_timeout

    def request_json(request_class, path:, headers:, body: nil)
      uri = build_uri(path)
      request = request_class.new(uri)
      headers.each { |key, value| request[key] = value }
      request["Content-Type"] = "application/json" if body
      request.body = JSON.generate(body) if body

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: open_timeout,
        read_timeout: read_timeout
      ) { |http| http.request(request) }

      Response.new(status: response.code.to_i, body: response.body.to_s, headers: response.to_hash)
    rescue JSON::GeneratorError, SocketError, Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET => e
      raise ProviderError.new(
        code: "github_api_unreachable",
        message: "GitHub API request failed: #{e.class}",
        safe_detail: "GitHub API is temporarily unreachable.",
        http_status: :bad_gateway
      )
    end

    def build_uri(path)
      base_url = api_base_url.end_with?("/") ? api_base_url : "#{api_base_url}/"
      URI.join(base_url, path.delete_prefix("/"))
    end
  end
end
