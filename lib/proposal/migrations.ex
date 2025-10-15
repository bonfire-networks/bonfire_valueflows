defmodule ValueFlows.Proposal.Migrations do
  @moduledoc false
  use Ecto.Migration
  import Needle.Migration

  def up do
    create_pointable_table(ValueFlows.Proposal) do
      add(:name, :string)
      add(:note, :text)

      add_pointer(:creator_id, :weak, ValueFlows.Util.user_schema(), null: true)
      add_pointer(:eligible_location_id, :weak, Bonfire.Geolocate.Geolocation, null: true)
      add_pointer(:context_id, :weak, Needle.Pointer, null: true)

      add(:unit_based, :boolean, default: false)

      add(:has_beginning, :timestamptz)
      add(:has_end, :timestamptz)
      add(:created, :timestamptz)

      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    create_pointable_table(ValueFlows.Proposal.ProposedIntent) do
      add(:reciprocal, :boolean, null: true)
      add(:deleted_at, :timestamptz)

      add_pointer(:publishes_id, :strong, ValueFlows.Planning.Intent, null: false)
      add_pointer(:published_in_id, :strong, ValueFlows.Proposal, null: false)
    end

    create_pointable_table(ValueFlows.Proposal.ProposedTo) do
      add(:deleted_at, :timestamptz)
      add_pointer(:proposed_to_id, :weak, Needle.Pointer, null: false)
      add_pointer(:proposed_id, :weak, Needle.Pointer, null: false)
    end
  end

  def down do
    drop_pointable_table(ValueFlows.Proposal.ProposedTo)
    drop_pointable_table(ValueFlows.Proposal.ProposedIntent)
    drop_pointable_table(ValueFlows.Proposal)
  end
end
