# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Claim.Migrations do
  @moduledoc false
  use Ecto.Migration

  import Needle.Migration

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

      add_pointer(:provider_id, :weak, Needle.Pointer, null: true)
      add_pointer(:receiver_id, :weak, Needle.Pointer, null: true)
      add_pointer(:resource_conforms_to_id, :weak, ResourceSpecification, null: true)
      add_pointer(:triggered_by_id, :weak, EconomicEvent, null: true)
      add_pointer(:resource_quantity_id, :weak, Bonfire.Quantify.Measure, null: true)
      add_pointer(:effort_quantity_id, :weak, Bonfire.Quantify.Measure, null: true)
      add_pointer(:creator_id, :weak, ValueFlows.Util.user_schema(), null: true)
      add_pointer(:context_id, :weak, Needle.Pointer, null: true)

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
