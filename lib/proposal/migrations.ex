defmodule ValueFlows.Proposal.Migrations do
  @moduledoc false
  use Ecto.Migration
  import Needle.Migration

  def up do
    create_pointable_table(ValueFlows.Proposal) do
      add(:name, :string)
      add(:note, :text)

      add(:creator_id, weak_pointer(ValueFlows.Util.user_schema()), null: true)

      add(:eligible_location_id, weak_pointer(Bonfire.Geolocate.Geolocation), null: true)

      # optional context as scope
      add(:context_id, weak_pointer(), null: true)

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
      # Note: null allowed
      add(:reciprocal, :boolean, null: true)
      add(:deleted_at, :timestamptz)

      add(:publishes_id, strong_pointer(ValueFlows.Planning.Intent), null: false)

      add(:published_in_id, strong_pointer(ValueFlows.Proposal), null: false)
    end

    create_pointable_table(ValueFlows.Proposal.ProposedTo) do
      add(:deleted_at, :timestamptz)
      add(:proposed_to_id, weak_pointer(), null: false)
      add(:proposed_id, weak_pointer(), null: false)
    end
  end

  def down do
    drop_pointable_table(ValueFlows.Proposal.ProposedTo)
    drop_pointable_table(ValueFlows.Proposal.ProposedIntent)
    drop_pointable_table(ValueFlows.Proposal)
  end
end
