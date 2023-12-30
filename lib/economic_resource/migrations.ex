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

      add(:image_id, weak_pointer(ValueFlows.Util.image_schema()), null: true)

      add(:conforms_to_id, weak_pointer(ResourceSpecification), null: true)

      # add(:resource_classified_as, {:array, :string}, virtual: true)

      add(:current_location_id, weak_pointer(Bonfire.Geolocate.Geolocation), null: true)

      add(:contained_in_id, weak_pointer(EconomicResource), null: true)

      add(:state_id, :string)

      # usually linked to Agent
      add(:primary_accountable_id, weak_pointer(), null: true)

      add(:accounting_quantity_id, weak_pointer(Bonfire.Quantify.Measure), null: true)

      add(:onhand_quantity_id, weak_pointer(Bonfire.Quantify.Measure), null: true)

      add(:unit_of_effort_id, weak_pointer(Bonfire.Quantify.Unit), null: true)

      add(:stage_id, weak_pointer(ProcessSpecification), null: true)

      # optional context as in_scope_of
      add(:context_id, weak_pointer(), null: true)

      add(:creator_id, weak_pointer(ValueFlows.Util.user_schema()), null: true)

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
