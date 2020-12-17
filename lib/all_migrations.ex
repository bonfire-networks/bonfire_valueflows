defmodule ValueFlows.AllMigrations do
  @moduledoc """
  Catch-all migrations intended to be used to initialise new Bonfire apps.
  Add any new up/down ecto migrations in VF modules to the bottom of these two functions.
  """
  def up do
    ValueFlows.Planning.Intent.Migrations.up()

    ValueFlows.Proposal.Migrations.up()

    ValueFlows.Knowledge.ResourceSpecification.Migrations.up()
    ValueFlows.Knowledge.ProcessSpecification.Migrations.up()

    ValueFlows.Observation.EconomicResource.Migrations.up()
    ValueFlows.Observation.Process.Migrations.up()
    ValueFlows.Observation.EconomicEvent.Migrations.up()

    ValueFlows.Planning.Intent.Migrations.add_references()

    ValueFlows.Claim.Migrations.up()

    ValueFlows.ValueCalculation.Migrations.up()
  end

  def down do
    ValueFlows.Planning.Intent.Migrations.down()

    ValueFlows.Proposal.Migrations.down()

    ValueFlows.Knowledge.ResourceSpecification.Migrations.down()
    ValueFlows.Knowledge.ProcessSpecification.Migrations.down()

    ValueFlows.Observation.EconomicResource.Migrations.down()
    ValueFlows.Observation.Process.Migrations.down()
    ValueFlows.Observation.EconomicEvent.Migrations.down()

    ValueFlows.Planning.Intent.Migrations.add_references()

    ValueFlows.Claim.Migrations.down()

    ValueFlows.ValueCalculation.Migrations.down()
  end
end
