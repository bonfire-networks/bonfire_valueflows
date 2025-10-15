defmodule ValueFlows.Planning.Satisfaction.Migrations do
  @moduledoc false
  use Ecto.Migration

  import Needle.Migration

  alias ValueFlows.Planning.Intent
  alias ValueFlows.Planning.Satisfaction

  alias ValueFlows.EconomicEvent
  alias Bonfire.Quantify.Measure

  def up() do
    create_pointable_table(Satisfaction) do
      add_pointer(:satisfies_id, :weak, Intent)
      add_pointer(:satisfied_by_id, :weak, Needle.Pointer)
      add_pointer(:resource_quantity_id, :weak, Measure)
      add_pointer(:effort_quantity_id, :weak, Measure)

      add(:note, :text)

      add_pointer(:creator_id, :weak, ValueFlows.Util.user_schema())

      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end
  end

  def down(),
    do: drop_pointable_table(Satisfaction)
end
