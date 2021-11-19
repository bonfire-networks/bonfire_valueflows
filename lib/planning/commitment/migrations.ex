defmodule ValueFlows.Planning.Commitment.Migrations do
  use Ecto.Migration

  import Pointers.Migration

  alias ValueFlows.Planning.Commitment
  alias ValueFlows.Process
  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.EconomicResource
  alias Bonfire.Quantify.Measure
  alias Bonfire.Geolocate.Geolocation

  def up() do
    create_pointable_table(Commitment) do
      add :action_id, :string, null: false

      add :input_of_id, weak_pointer(Process)
      add :output_of_id, weak_pointer(Process)

      add :provider_id, weak_pointer()
      add :receiver_id, weak_pointer()

      add :resource_conforms_to_id, weak_pointer(ResourceSpecification)
      add :resource_inventoried_as_id, weak_pointer(EconomicResource)

      add :resource_quantity_id, weak_pointer(Measure)
      add :effort_quantity_id, weak_pointer(Measure)

      add :has_beginning, :timestamptz
      add :has_end, :timestamptz
      add :has_point_in_time, :timestamptz
      add :due, :timestamptz

      add :finished, :boolean, default: false, null: false
      add :deletable, :boolean, default: false, null: false
      add :note, :text
      add :agreed_in, :string

      add :context_id, weak_pointer() # inScopeOf

      #add :clause_of_id, week_pointer(Agreement)

      add :at_location_id, weak_pointer(Geolocation)

      #add :independent_demand_of_id, week_pointer(Plan)

      add :creator_id, weak_pointer(ValueFlows.Util.user_schema())

      add :published_at, :timestamptz
      add :deleted_at, :timestamptz
      add :disabled_at, :timestamptz

      timestamps inserted_at: false, type: :utc_datetime_usec
    end
  end

  def down(),
    do: drop_pointable_table(Commitment)
end
