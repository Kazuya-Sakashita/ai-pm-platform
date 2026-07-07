require "rails_helper"

RSpec.describe "parameter filtering" do
  it "GitHub callback stateをログ用パラメータからマスクする" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter(
      "state" => "signed-github-callback-state",
      "repository" => "Kazuya-Sakashita/ai-pm-platform"
    )

    expect(filtered.fetch("state")).to eq("[FILTERED]")
    expect(filtered.fetch("repository")).to eq("Kazuya-Sakashita/ai-pm-platform")
  end
end
