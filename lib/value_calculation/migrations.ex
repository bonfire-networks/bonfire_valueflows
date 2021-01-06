# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.ValueCalculation.Migrations do
  use Ecto.Migration

  import Pointers.Migration

  def up do
    create_pointable_table(ValueFlows.ValueCalculation) do
      # TODO: consider max size
      add(:formula, :string, length: 5000, null: false)

      add(:creator_id, weak_pointer(ValueFlows.Util.user_schema()), null: true)
      add(:context_id, weak_pointer(), null: true)
      add(:value_unit_id, weak_pointer(Bonfire.Quantify.Unit), null: true)

      add(:deleted_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end
  end

  def down do
    drop_pointable_table(ValueFlows.ValueCalculation)
  end
end
