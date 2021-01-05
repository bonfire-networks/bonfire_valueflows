defmodule ValueFlows.Process.Migrations do
  use Ecto.Migration
  # alias Pointers.ULID
  import Pointers.Migration

  # alias ValueFlows.Process
  alias ValueFlows.Knowledge.ProcessSpecification

  # defp resource_table(), do: EconomicResource.__schema__(:source)

  def up do
    create_pointable_table(ValueFlows.Process) do
      add(:name, :string)
      add(:note, :text)

      # add(:image_id, weak_pointer(ValueFlows.Util.image_schema()), null: true)

      add(:has_beginning, :timestamptz)
      add(:has_end, :timestamptz)

      add(:finished, :boolean, default: false)

      # add(:resource_classified_as, {:array, :string}, virtual: true)

      add(:based_on_id, weak_pointer(ProcessSpecification), null: true)

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
    drop_pointable_table(ValueFlows.Process)
  end

end
