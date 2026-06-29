#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "open3"
require "pathname"

ROOT = Pathname(__dir__).parent.expand_path
ISSUE_DIR = ROOT.join("docs/issue")

def usage
  warn "Usage: scripts/sync-github-issues.rb [--dry-run|--apply]"
  exit 2
end

mode = ARGV.fetch(0, "--dry-run")
usage unless ["--dry-run", "--apply"].include?(mode)

def run!(*cmd)
  stdout, stderr, status = Open3.capture3(*cmd, chdir: ROOT.to_s)
  return stdout if status.success?

  detail = stderr.empty? ? stdout : stderr
  raise "#{cmd.join(' ')} failed\n#{detail}"
end

def github_issue_url?(text)
  text.match?(%r{https://github\.com/[^/\s]+/[^/\s]+/issues/\d+})
end

def issue_title(path)
  heading = File.readlines(path, chomp: true).find { |line| line.start_with?("# ") }
  raise "Missing H1 title in #{path}" unless heading

  heading.delete_prefix("# ").strip
end

def replace_github_issue_section(body, url)
  replacement = <<~MARKDOWN.rstrip
    ## GitHub Issue

    #{url}

    登録日: #{Date.today.iso8601}
    同期方法: `scripts/sync-github-issues.rb --apply`
  MARKDOWN

  if body.match?(/^## GitHub Issue\n.*?(?=^## |\z)/m)
    body.sub(/^## GitHub Issue\n.*?(?=^## |\z)/m, "#{replacement}\n\n")
  else
    body.sub(/\A(# .+\n)/, "\\1\n#{replacement}\n\n")
  end
end

issue_paths = ISSUE_DIR.glob("ISSUE-*.md").sort
abort "No issue files found in #{ISSUE_DIR}" if issue_paths.empty?

if mode == "--apply"
  run!("gh", "api", "user", "--jq", ".login")
  remotes = run!("git", "remote", "-v")
  abort "No git remote configured. Add origin before applying." if remotes.strip.empty?
end

pending_paths = issue_paths.reject { |path| github_issue_url?(path.read) }

puts "Found #{issue_paths.size} local issue docs."
puts "Pending GitHub issues: #{pending_paths.size}"

pending_paths.each do |path|
  title = issue_title(path)
  relative_path = path.relative_path_from(ROOT).to_s

  if mode == "--dry-run"
    puts "DRY-RUN gh issue create --title #{title.inspect} --body-file #{relative_path}"
    next
  end

  output = run!("gh", "issue", "create", "--title", title, "--body-file", relative_path)
  url = output.lines.find { |line| line.include?("https://github.com/") }&.strip
  raise "Could not parse GitHub issue URL from gh output for #{relative_path}: #{output}" unless url

  path.write(replace_github_issue_section(path.read, url))
  puts "Created #{url} from #{relative_path}"
end
