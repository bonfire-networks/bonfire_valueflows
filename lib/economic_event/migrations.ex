defmodule ValueFlows.EconomicEvent.Migrations do
  @moduledoc false
  use Ecto.Migration
  # alias Needle.ULID
  import Needle.Migration

  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.EconomicEvent
  alias ValueFlows.EconomicResource
  alias ValueFlows.Process

  # defp event_table(), do: EconomicEvent.__schema__(:source)

  def up do
    create_pointable_table(ValueFlows.EconomicEvent) do
      # add(:name, :string)
      add(:note, :text)

      # add(:image_id, weak_pointer(ValueFlows.Util.image_schema()), null: true)

      add(:action_id, :string)

      add_pointer(:input_of_id, :weak, Process, null: true)
      add_pointer(:output_of_id, :weak, Process, null: true)

      add_pointer(:provider_id, :weak, Needle.Pointer, null: true)
      add_pointer(:receiver_id, :weak, Needle.Pointer, null: true)

      add_pointer(:resource_inventoried_as_id, :weak, EconomicResource, null: true)

      add_pointer(:to_resource_inventoried_as_id, :weak, EconomicResource, null: true)

      # add(:resource_classified_as, {:array, :string}, virtual: true)

      add_pointer(:resource_conforms_to_id, :weak, ResourceSpecification, null: true)

      add_pointer(:resource_quantity_id, :weak, Bonfire.Quantify.Measure, null: true)

      add_pointer(:effort_quantity_id, :weak, Bonfire.Quantify.Measure, null: true)

      add(:has_beginning, :timestamptz)
      add(:has_end, :timestamptz)
      add(:has_point_in_time, :timestamptz)

      # optional context as in_scope_of
      add_pointer(:context_id, :weak, Needle.Pointer, null: true)

      # TODO: use string or link to Agreement?
      add(:agreed_in, :string)
      # belongs_to(:agreed_in, Agreement)

      add_pointer(:at_location_id, :weak, Bonfire.Geolocate.Geolocation, null: true)

      add_pointer(:triggered_by_id, :weak, EconomicEvent, null: true)

      add_pointer(:calculated_using_id, :weak, ValueFlows.ValueCalculation, null: true)

      add_pointer(:creator_id, :weak, ValueFlows.Util.user_schema(), null: true)

      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end
  end

  def down do
    drop_pointable_table(ValueFlows.EconomicEvent)
  end
end
