defmodule ValueFlows.Process.Migrations do
  @moduledoc false
  use Ecto.Migration
  # alias Needle.ULID
  import Needle.Migration

  # alias ValueFlows.Process
  alias ValueFlows.Knowledge.ProcessSpecification

  # defp resource_table(), do: EconomicResource.__schema__(:source)

  # the table, named here because Process's source is a view over it
  @process_table "vf_process"
  @process_table_id "4AYF0R1NPVTST0BEC0ME0VTPVT"

  def up do
    # create_pointable_table(ValueFlows.Process) do
    create_pointable_table(@process_table, @process_table_id) do
      add(:name, :string)
      add(:note, :text)

      # add(:image_id, weak_pointer(ValueFlows.Util.image_schema()), null: true)

      add(:has_beginning, :timestamptz)
      add(:has_end, :timestamptz)

      add(:finished, :boolean, default: false)

      add_pointer(:based_on_id, :weak, ProcessSpecification, null: true)
      add_pointer(:context_id, :weak, Needle.Pointer, null: true)
      add_pointer(:creator_id, :weak, ValueFlows.Util.user_schema(), null: true)

      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end
  end

  def down do
    # drop_pointable_table(ValueFlows.Process)
    drop_pointable_table(@process_table, @process_table_id)
  end
end
