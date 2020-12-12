defmodule Bonfire.ValueFlows.Repo.Migrations.ImportMe do
  use Ecto.Migration

  import Bonfire.ValueFlows.Migration
  # accounts & users

  def change, do: migrate_thesis

end
