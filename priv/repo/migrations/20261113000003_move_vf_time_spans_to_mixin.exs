defmodule ValueFlows.Repo.Migrations.MoveVfTimeSpansToMixin do
  @moduledoc false
  # moves `has_beginning` and `has_end` of each VF type that has them into the `Bonfire.Data.Time.TimeSpan` mixin, behind a writable view per table (`<table>_view`) which the type's schema uses as its source
  use Ecto.Migration
  import Needle.Migration

  # required: inner-joined, so an index on the mixin can serve an order by date; every row then gets a time span row
  @mixins [{"bonfire_data_time_span", ["has_beginning", "has_end"], required: true}]

  # Intent, Commitment, EconomicEvent, Proposal, Process
  @tables ~w(vf_intent vf_commitment vf_event vf_proposal vf_process)

  def up do
    for table <- @tables, do: move_columns_to_mixins(table, table <> "_view", @mixins)
  end

  def down do
    for table <- Enum.reverse(@tables), do: move_columns_from_mixins(table, table <> "_view", @mixins)
  end

  # Intent's `has_beginning` alone, as this migration first was:
  #
  # @table "vf_intent"
  # @view "vf_intent_view"
  # @mixins [{"bonfire_data_time_span", ["has_beginning"], required: true}]
  #
  # def up, do: move_columns_to_mixins(@table, @view, @mixins)
  # def down, do: move_columns_from_mixins(@table, @view, @mixins)
end
