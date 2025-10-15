defmodule ValueFlows.EconomicResource.Migrations do
  @moduledoc false
  use Ecto.Migration
  # alias Needle.ULID
  import Needle.Migration

  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.Knowledge.ProcessSpecification
  alias ValueFlows.EconomicResource
  # alias ValueFlows.EconomicEvent
  # alias ValueFlows.Process

  # defp resource_table(), do: EconomicResource.__schema__(:source)

  def up do
    create_pointable_table(ValueFlows.EconomicResource) do
      add(:name, :string)
      add(:note, :text)
      add(:tracking_identifier, :text)

      add_pointer(:image_id, :weak, ValueFlows.Util.image_schema(), null: true)
      add_pointer(:conforms_to_id, :weak, ResourceSpecification, null: true)
      add_pointer(:current_location_id, :weak, Bonfire.Geolocate.Geolocation, null: true)
      add_pointer(:contained_in_id, :weak, EconomicResource, null: true)

      add(:state_id, :string)

      # usually linked to Agent
      add_pointer(:primary_accountable_id, :weak, Needle.Pointer, null: true)

      add_pointer(:accounting_quantity_id, :weak, Bonfire.Quantify.Measure, null: true)
      add_pointer(:onhand_quantity_id, :weak, Bonfire.Quantify.Measure, null: true)
      add_pointer(:unit_of_effort_id, :weak, Bonfire.Quantify.Unit, null: true)

      add_pointer(:stage_id, :weak, ProcessSpecification, null: true)

      # optional context as in_scope_of
      add_pointer(:context_id, :weak, Needle.Pointer, null: true)

      add_pointer(:creator_id, :weak, ValueFlows.Util.user_schema(), null: true)

      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end
  end

  def down do
    drop_pointable_table(ValueFlows.EconomicResource)
  end
end
