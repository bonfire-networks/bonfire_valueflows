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

      add_pointer(:image_id, :weak, ValueFlows.Util.image_schema(), null: true)
      add_pointer(:provider_id, :weak, Needle.Pointer, null: true)
      add_pointer(:receiver_id, :weak, Needle.Pointer, null: true)
      add_pointer(:at_location_id, :weak, Bonfire.Geolocate.Geolocation, null: true)
      add_pointer(:available_quantity_id, :weak, Bonfire.Quantify.Measure, null: true)
      add_pointer(:resource_quantity_id, :weak, Bonfire.Quantify.Measure, null: true)
      add_pointer(:effort_quantity_id, :weak, Bonfire.Quantify.Measure, null: true)
      add_pointer(:creator_id, :weak, ValueFlows.Util.user_schema(), null: true)
      add_pointer(:context_id, :weak, Needle.Pointer, null: true)

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
    table = intent_table()

    # needed to avoid error: constraint x for relation "vf_intent" already exists
    execute("ALTER TABLE #{table} DROP CONSTRAINT IF EXISTS vf_intent_input_of_id_fkey;")
    execute("ALTER TABLE #{table} DROP CONSTRAINT IF EXISTS vf_intent_output_of_id_fkey;")

    execute(
      "ALTER TABLE #{table} DROP CONSTRAINT IF EXISTS vf_intent_resource_conforms_to_id_fkey;"
    )

    execute(
      "ALTER TABLE #{table} DROP CONSTRAINT IF EXISTS vf_intent_resource_inventoried_as_id_fkey;"
    )

    alter table(table) do
      add_pointer(:input_of_id, :weak, Process, null: true)
      add_pointer(:output_of_id, :weak, Process, null: true)

      add_pointer(
        :resource_conforms_to_id,
        :weak,
        ResourceSpecification,
        null: true
      )

      add_pointer(
        :resource_inventoried_as_id,
        :weak,
        EconomicResource,
        null: true
      )
    end
  end

  def down do
    drop_pointable_table(ValueFlows.Planning.Intent)
  end
end
