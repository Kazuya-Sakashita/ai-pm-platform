require "spec_helper"
require "stringio"

require_relative "../../../scripts/solid-queue-worker-smoke-readiness"

RSpec.describe SolidQueueWorkerSmokeReadiness do
  let(:smoke) { described_class.new(env: {}, stdout: StringIO.new, stderr: StringIO.new) }

  it "Rails runner未使用時のnext actionを返す" do
    actions = smoke.send(:next_actions_for, ["rails_environment_not_loaded"])

    expect(actions).to include(
      "backendディレクトリからbundle exec ruby bin/rails runner ../scripts/solid-queue-worker-smoke-readiness.rbで実行する。"
    )
  end

  it "Solid Queue table未準備時のnext actionを返す" do
    actions = smoke.send(:next_actions_for, ["solid_queue_tables_unavailable"])

    expect(actions).to include(
      "staging/production-equivalent環境でqueue_schema適用済みのQUEUE_DATABASE_URLを設定して再実行する。"
    )
  end

  it "worker heartbeat未確認時のnext actionを重複なしで返す" do
    actions = smoke.send(:next_actions_for, ["worker_heartbeat_missing", "worker_heartbeat_stale"])

    expect(actions).to eq(["worker processを起動または再起動し、60秒以内のheartbeatを確認する。"])
  end
end
