require "rails_helper"
require "erb"
require "yaml"

RSpec.describe "Solid Queue configuration" do
  def load_yaml(path)
    YAML.safe_load(
      ERB.new(Rails.root.join(path).read).result,
      aliases: true
    )
  end

  it "uses explicit production queues for the AI PM job classes" do
    queue_config = load_yaml("config/queue.yml")
    queues = queue_config.fetch("production").fetch("workers").first.fetch("queues")

    expect(queues).to eq(
      %w[
        github_reconciliation
        ai_generation
        ai_review
        default
      ]
    )
  end

  it "defines a production queue database for Solid Queue" do
    database_config = load_yaml("config/database.yml")
    production = database_config.fetch("production")

    expect(production.keys).to include("primary", "queue")
    expect(production.fetch("queue").fetch("migrations_paths")).to eq("db/queue_migrate")
  end
end
