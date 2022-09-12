defmodule ValueFlows.Planning.Satisfaction.Migrations do
  use Ecto.Migration

  import Pointers.Migration

  alias ValueFlows.Planning.Intent
  alias ValueFlows.Planning.Satisfaction

  alias ValueFlows.EconomicEvent
  alias Bonfire.Quantify.Measure

  def up() do
    create_pointable_table(Satisfaction) do
      add(:satisfies_id, weak_pointer(Intent))
      # EconomicEvent or Commitment
      add(:satisfied_by_id, weak_pointer())

      add(:resource_quantity_id, weak_pointer(Measure))
      add(:effort_quantity_id, weak_pointer(Measure))

      add(:note, :text)

      add(:creator_id, weak_pointer(ValueFlows.Util.user_schema()))

      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end
  end

  def down(),
    do: drop_pointable_table(Satisfaction)
end
