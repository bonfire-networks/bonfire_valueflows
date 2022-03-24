defmodule ValueFlows.Proposal.ProposedIntentQueries do
  import Ecto.Query
  import Where

  alias ValueFlows.Proposal.ProposedIntent

  def query(ProposedIntent) do
    from(pi in ProposedIntent, as: :proposed_intent)
  end

  def query(filters), do: query(ProposedIntent, filters)

  def query(q, filters), do: filter(query(q), filters)

  def join_to(q, spec, join_qualifier \\ :left)

  def join_to(q, specs, jq) when is_list(specs) do
    Enum.reduce(specs, q, &join_to(&2, &1, jq))
  end

  def join_to(q, :publishes, jq) do
    join(q, jq, [proposed_intent: pi], i in assoc(pi, :publishes), as: :publishes)
  end

  def join_to(q, :published_in, jq) do
    join(q, jq, [proposed_intent: pi], p in assoc(pi, :published_in), as: :published_in)
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
    where(q, [proposed_intent: pi], is_nil(pi.deleted_at))
  end

  # by field values

  def filter(q, {:id, id}) when is_binary(id) do
    where(q, [proposed_intent: pi], pi.id == ^id)
  end

  def filter(q, {:id, ids}) when is_list(ids) do
    where(q, [proposed_intent: pi], pi.id in ^ids)
  end

  def filter(q, {:publishes_id, id}) when is_binary(id) do
    where(q, [proposed_intent: pi], pi.publishes_id == ^id)
  end

  def filter(q, {:publishes_id, ids}) when is_list(ids) do
    where(q, [proposed_intent: pi], pi.publishes_id in ^ids)
  end

  def filter(q, {:published_in_id, id}) when is_binary(id) do
    where(q, [proposed_intent: pi], pi.published_in_id == ^id)
  end

  def filter(q, {:published_in_id, ids}) when is_list(ids) do
    where(q, [proposed_intent: pi], pi.published_in_id in ^ids)
  end

  # grouping

  def filter(q, {:group_count, key}) when is_atom(key) do
    filter(q, group: key, count: key)
  end

  def filter(q, {:group, key}) when is_atom(key) do
    group_by(q, [proposed_intent: c], field(c, ^key))
  end

  def filter(q, {:count, key}) when is_atom(key) do
    select(q, [proposed_intent: c], {field(c, ^key), count(c.id)})
  end

  def filter(q, other_filter), do: ValueFlows.Util.common_filters(q, other_filter)
end
