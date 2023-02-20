# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.ValueCalculation.Migrations do
  @moduledoc false
  use Ecto.Migration

  import Pointers.Migration

  def up do
    create_pointable_table(ValueFlows.ValueCalculation) do
      add(:name, :text, null: true)
      add(:note, :text, null: true)
      add(:formula, :text, null: false)

      add(:creator_id, weak_pointer(ValueFlows.Util.user_schema()), null: true)
      add(:context_id, weak_pointer(), null: true)
      add(:value_unit_id, weak_pointer(Bonfire.Quantify.Unit), null: false)

      add(:action_id, :string, null: false)
      add(:value_action_id, :string, null: false)

      add(
        :resource_conforms_to_id,
        weak_pointer(ValueFlows.Knowledge.ResourceSpecification)
      )

      add(
        :value_resource_conforms_to_id,
        weak_pointer(ValueFlows.Knowledge.ResourceSpecification)
      )

      add(:deleted_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end
  end

  def down do
    drop_pointable_table(ValueFlows.ValueCalculation)
  end
end
