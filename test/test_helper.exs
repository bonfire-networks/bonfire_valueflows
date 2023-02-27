ExUnit.start(exclude: Bonfire.Common.RuntimeConfig.skip_test_tags())

Ecto.Adapters.SQL.Sandbox.mode(
  Bonfire.Common.Config.repo(),
  :manual
)
