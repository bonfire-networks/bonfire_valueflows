defmodule ValueFlows.Planning.Commitment.Migrations do
  @moduledoc false
  use Ecto.Migration

  import Needle.Migration

  alias ValueFlows.Planning.Commitment
  alias ValueFlows.Process
  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.EconomicResource
  alias Bonfire.Quantify.Measure
  alias Bonfire.Geolocate.Geolocation

  def up() do
    create_pointable_table(Commitment) do
      add(:action_id, :string, null: false)

      add_pointer(:input_of_id, :weak, Process)
      add_pointer(:output_of_id, :weak, Process)

      add_pointer(:provider_id, :weak, Needle.Pointer)
      add_pointer(:receiver_id, :weak, Needle.Pointer)

      add_pointer(:resource_conforms_to_id, :weak, ResourceSpecification)
      add_pointer(:resource_inventoried_as_id, :weak, EconomicResource)

      add_pointer(:resource_quantity_id, :weak, Measure)
      add_pointer(:effort_quantity_id, :weak, Measure)

      add(:has_beginning, :timestamptz)
      add(:has_end, :timestamptz)
      add(:has_point_in_time, :timestamptz)
      add(:due, :timestamptz)

      add(:finished, :boolean, default: false, null: false)
      add(:deletable, :boolean, default: false, null: false)
      add(:note, :text)
      add(:agreed_in, :string)

      add_pointer(:context_id, :weak, Needle.Pointer)
      add_pointer(:at_location_id, :weak, Geolocation)

      add_pointer(:at_location_id, :weak, ValueFlows.Util.user_schema())

      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end
  end

  def down(),
    do: drop_pointable_table(Commitment)
end
