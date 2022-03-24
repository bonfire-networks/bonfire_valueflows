defmodule ValueFlows.Proposal.ProposedToQueries do
  import Ecto.Query
  import Where

  alias ValueFlows.Proposal.ProposedTo

  def query(ProposedTo) do
    from(pt in ProposedTo, as: :proposed_to)
  end

  def query(filters), do: query(ProposedTo, filters)

  def query(q, filters), do: filter(query(q), filters)

  def join_to(q, spec, join_qualifier \\ :left)

  def join_to(q, specs, jq) when is_list(specs) do
    Enum.reduce(specs, q, &join_to(&2, &1, jq))
  end

  def filter(q, filters) when is_list(filters) do
    Enum.reduce(filters, q, &filter(&2, &1))
  end

  ## joins
  def filter(q, {:join, {join, qual}}), do: join_to(q, join, qual)
  def filter(q, {:join, join}), do: join_to(q, join)

  # by preset

  def filter(q, :default) do
    filter(q, [:deleted])
  end

  def filter(q, :deleted) do
    where(q, [proposed_to: pt], is_nil(pt.deleted_at))
  end

  # by field values

  def filter(q, {:id, id}) when is_binary(id) do
    where(q, [proposed_to: pt], pt.id == ^id)
  end

  def filter(q, {:id, ids}) when is_list(ids) do
    where(q, [proposed_to: pt], pt.id in ^ids)
  end

  def filter(q, {:proposed_to_id, id}) when is_binary(id) do
    where(q, [proposed_to: pt], pt.proposed_to_id == ^id)
  end

  def filter(q, {:proposed_to_id, ids}) when is_list(ids) do
    where(q, [proposed_to: pt], pt.proposed_to_id in ^ids)
  end

  def filter(q, {:proposed_id, id}) when is_binary(id) do
    where(q, [proposed_to: pt], pt.proposed_id == ^id)
  end

  def filter(q, {:proposed_id, ids}) when is_list(ids) do
    where(q, [proposed_to: pt], pt.proposed_id in ^ids)
  end

  # grouping

  def filter(q, {:group_count, key}) when is_atom(key) do
    filter(q, group: key, count: key)
  end

  def filter(q, {:group, key}) when is_atom(key) do
    group_by(q, [proposed_to: pt], field(pt, ^key))
  end

  def filter(q, {:count, key}) when is_atom(key) do
    select(q, [proposed_to: pt], {field(pt, ^key), count(pt.id)})
  end

  def filter(q, other_filter), do: ValueFlows.Util.common_filters(q, other_filter)
end
