defmodule Bonfire.Repo.Migrations.ImportCommitmentSatisfaction do
  @moduledoc false
  use Ecto.Migration

  def up do
    ValueFlows.Planning.Commitment.Migrations.up()
    ValueFlows.Planning.Satisfaction.Migrations.up()
  end

  def down do
    ValueFlows.Planning.Satisfaction.Migrations.down()
    ValueFlows.Planning.Commitment.Migrations.down()
  end
end
