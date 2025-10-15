defmodule ValueFlows.Knowledge.ResourceSpecification.Migrations do
  @moduledoc false
  use Ecto.Migration
  # alias Needle.ULID
  import Needle.Migration

  # alias ValueFlows.Knowledge.ResourceSpecification
  # alias ValueFlows.EconomicResource
  # alias ValueFlows.EconomicEvent

  # defp resource_table(), do: EconomicResource.__schema__(:source)

  def up do
    create_pointable_table(ValueFlows.Knowledge.ResourceSpecification) do
      add(:name, :string)
      add(:note, :text)

      add_pointer(:image_id, :weak, ValueFlows.Util.image_schema(), null: true)
      add_pointer(:default_unit_of_effort_id, :weak, Bonfire.Quantify.Unit, null: true)
      add_pointer(:context_id, :weak, Needle.Pointer, null: true)
      add_pointer(:creator_id, :weak, ValueFlows.Util.user_schema(), null: true)

      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end
  end

  def down do
    drop_pointable_table(ValueFlows.Knowledge.ResourceSpecification)
  end
end
