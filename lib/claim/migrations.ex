# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Claim.Migrations do
  @moduledoc false
  use Ecto.Migration

  import Pointers.Migration

  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.EconomicEvent

  def up do
    create_pointable_table(ValueFlows.Claim) do
      add(:note, :text)
      add(:agreed_in, :text)
      add(:action_id, :string)

      add(:finished, :boolean)
      add(:created, :timestamptz)
      add(:due, :timestamptz)

      add(:provider_id, weak_pointer(), null: true)
      add(:receiver_id, weak_pointer(), null: true)

      add(:resource_conforms_to_id, weak_pointer(ResourceSpecification), null: true)

      add(:triggered_by_id, weak_pointer(EconomicEvent), null: true)

      add(:resource_quantity_id, weak_pointer(Bonfire.Quantify.Measure), null: true)

      add(:effort_quantity_id, weak_pointer(Bonfire.Quantify.Measure), null: true)

      add(:creator_id, weak_pointer(ValueFlows.Util.user_schema()), null: true)
      add(:context_id, weak_pointer(), null: true)

      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end
  end

  def down do
    drop_pointable_table(ValueFlows.Claim)
  end
end
