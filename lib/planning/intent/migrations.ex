defmodule ValueFlows.Planning.Intent.Migrations do
  @moduledoc false
  use Ecto.Migration
  # alias Needle.ULID
  import Needle.Migration

  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.EconomicResource
  alias ValueFlows.Process
  # alias ValueFlows.Proposal

  defp intent_table(), do: ValueFlows.Planning.Intent.__schema__(:source)

  def up do
    create_pointable_table(ValueFlows.Planning.Intent) do
      add(:name, :string)
      add(:note, :text)

      # array of URI
      # add(:resource_classified_as, {:array, :string})

      add(:action_id, :string)

      add(:image_id, weak_pointer(ValueFlows.Util.image_schema()), null: true)

      add(:provider_id, weak_pointer(), null: true)
      add(:receiver_id, weak_pointer(), null: true)

      add(:at_location_id, weak_pointer(Bonfire.Geolocate.Geolocation), null: true)

      add(:available_quantity_id, weak_pointer(Bonfire.Quantify.Measure), null: true)

      add(:resource_quantity_id, weak_pointer(Bonfire.Quantify.Measure), null: true)

      add(:effort_quantity_id, weak_pointer(Bonfire.Quantify.Measure), null: true)

      add(:creator_id, weak_pointer(ValueFlows.Util.user_schema()), null: true)

      # optional context as scope
      add(:context_id, weak_pointer(), null: true)

      add(:finished, :boolean, default: false)

      # # field(:deletable, :boolean) # TODO - virtual field? how is it calculated?

      # belongs_to(:agreed_in, Agreement)

      # inverse relationships
      # has_many(:published_in, ProposedIntent)
      # has_many(:satisfied_by, Satisfaction)

      add(:has_beginning, :timestamptz)
      add(:has_end, :timestamptz)
      add(:has_point_in_time, :timestamptz)
      add(:due, :timestamptz)

      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end
  end

  def add_references do
    alter table(intent_table()) do
      add_if_not_exists(:input_of_id, weak_pointer(Process), null: true)
      add_if_not_exists(:output_of_id, weak_pointer(Process), null: true)

      add_if_not_exists(
        :resource_conforms_to_id,
        weak_pointer(ResourceSpecification),
        null: true
      )

      add_if_not_exists(
        :resource_inventoried_as_id,
        weak_pointer(EconomicResource),
        null: true
      )
    end
  end

  def down do
    drop_pointable_table(ValueFlows.Planning.Intent)
  end
end
