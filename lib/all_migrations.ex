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

    ValueFlows.ValueCalculation.Migrations.up()

    ValueFlows.EconomicResource.Migrations.up()
    ValueFlows.Process.Migrations.up()
    ValueFlows.EconomicEvent.Migrations.up()

    ValueFlows.Planning.Intent.Migrations.add_references()

    ValueFlows.Claim.Migrations.up()

    ValueFlows.Planning.Commitment.Migrations.up()
    ValueFlows.Planning.Satisfaction.Migrations.up()
  end

  def down do
    ValueFlows.Planning.Intent.Migrations.down()

    ValueFlows.Proposal.Migrations.down()

    ValueFlows.Knowledge.ResourceSpecification.Migrations.down()
    ValueFlows.Knowledge.ProcessSpecification.Migrations.down()

    ValueFlows.EconomicResource.Migrations.down()
    ValueFlows.Process.Migrations.down()
    ValueFlows.EconomicEvent.Migrations.down()

    ValueFlows.ValueCalculation.Migrations.down()

    ValueFlows.Claim.Migrations.down()
    ValueFlows.Planning.Commitment.Migrations.down()
    ValueFlows.Planning.Satisfaction.Migrations.down()
  end
end
