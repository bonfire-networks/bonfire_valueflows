# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.ValueCalculation.Migrations do
  @moduledoc false
  use Ecto.Migration

  import Needle.Migration

  def up do
    create_pointable_table(ValueFlows.ValueCalculation) do
      add(:name, :text, null: true)
      add(:note, :text, null: true)
      add(:formula, :text, null: false)

      add_pointer(:creator_id, :weak, ValueFlows.Util.user_schema(), null: true)
      add_pointer(:context_id, :weak, Needle.Pointer, null: true)
      add_pointer(:value_unit_id, :weak, Bonfire.Quantify.Unit, null: false)

      add(:action_id, :string, null: false)
      add(:value_action_id, :string, null: false)

      add_pointer(:resource_conforms_to_id, :weak, ValueFlows.Knowledge.ResourceSpecification)

      add_pointer(
        :value_resource_conforms_to_id,
        :weak,
        ValueFlows.Knowledge.ResourceSpecification
      )

      add(:deleted_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end
  end

  def down do
    drop_pointable_table(ValueFlows.ValueCalculation)
  end
end
