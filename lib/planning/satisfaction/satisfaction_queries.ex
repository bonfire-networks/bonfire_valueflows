defmodule ValueFlows.Planning.Satisfaction.Queries do
  import Ecto.Query
  import Where

  alias ValueFlows.Planning.Satisfaction

  def query(Satisfaction),
    do: from(s in Satisfaction, as: :satisfaction)

  def query(:count),
    do: from(s in Satisfaction, as: :satisfaction)

  def query(filters),
    do: query(Satisfaction, filters)

  def query(q, filters),
    do: filter(query(q), filters)

  def queries(query, _page_opts, base_filters, data_filters, count_filters) do
    base_q = query(query, base_filters)
    data_q = filter(base_q, data_filters)
    count_q = filter(base_q, count_filters)
    {data_q, count_q}
  end


  def join_to(q, spec, join_qualifier \\ :left)

  def join_to(q, specs, jq) when is_list(specs),
    do: Enum.reduce(specs, q, &join_to(&2, &1, jq))

  def join_to(q, :effort_quantity, jq),
    do: join(q, jq, [satisfaction: s], q in assoc(s, :effort_quantity), as: :effort_quantity)

  def join_to(q, :resource_quantity, jq),
    do: join(q, jq, [satisfaction: s], q in assoc(s, :resource_quantity), as: :resource_quantity)

  # filter
  def filter(q, filters) when is_list(filters),
    do: Enum.reduce(filters, q, &filter(&2, &1))

  def filter(q, :default),
    do: filter(q, [:deleted, order: :default, preload: :quantities])

  def filter(q, :deleted),
    do: where(q, [satisfaction: s], is_nil(s.deleted_at))

  def filter(q, :deleted, true),
    do: where(q, [satisfaction: s], not is_nil(s.deleted_at))

  def filter(q, :disabled),
    do: where(q, [satisfaction: s], is_nil(s.disabled_at))

  def filter(q, :private),
    do: where(q, [satisfaction: s], not is_nil(s.published_at))

  def filter(q, {:status, :open}),
    do: where(q, [satisfaction: s], s.finished == false)

  def filter(q, {:status, :closed}),
    do: where(q, [satisfaction: s], s.finished == true)


  # search
  def filter(q, {:search, text}),
    do: where(q, [satisfaction: s], ilike(s.note, ^"%#{text}%"))


  # user
  def filter(q, {:user, %{id: user_id}}) do
    q
    |> where([satisfaction: s], not is_nil(s.published_at) or s.creator_id == ^user_id)
    |> filter([:disabled])
  end


  # field
  def filter(q, {:id, id}) when is_binary(id),
    do: where(q, [satisfaction: s], s.id == ^id)

  def filter(q, {:id, ids}) when is_list(ids),
    do: where(q, [satisfaction: s], s.id in ^ids)

  def filter(q, {:satisfies_id, id}),
    do: where(q, [satisfaction: s], s.satisfies_id == ^id)

  def filter(q, {:satisfied_by_id, id}),
    do: where(q, [satisfaction: s], s.satisfied_by_id == ^id)


  # order
  def filter(q, {:order, :default}),
    do: order_by(q, [satisfaction: s], [desc: s.updated_at, asc: s.id])

  def filter(q, {:order, [desc: key]}),
    do: order_by(q, [satisfaction: s], desc: field(s, ^key))

  def filter(q, {:order, [asc: key]}),
    do: order_by(q, [satisfaction: s], asc: field(s, ^key))

  def filter(q, {:order, key}),
    do: filter(q, order: [desc: key])


  # group and count
  def filter(q, {:group_count, key}),
    do: filter(q, group: key, count: key)

  def filter(q, {:group, key}),
    do: group_by(q, [satisfaction: s], field(s, ^key))

  def filter(q, {:count, key}),
    do: select(q, [satisfaction: s], {field(s, ^key), count(s.id)})

  def filter(q, {:preload, :all}) do
    q
    |> preload([:satisfies, :satisfied_by])
    |> filter({:preload, :quantities})
  end

  def filter(q, {:preload, :quantities}) do
    q
    |> join_to([:effort_quantity, :resource_quantity])
    |> preload([:effort_quantity, :resource_quantity])
  end


  # pagination
  def filter(q, {:offset, offset}),
    do: offset(q, ^offset)

  def filter(q, {:limit, limit}),
    do: limit(q, ^limit)

  def filter(q, {:paginate_id, %{after: a, limit: limit}}) do
    limit = limit + 2

    q
    |> where([satisfaction: s], s.id >= ^a)
    |> limit(^limit)
  end

  def filter(q, {:paginate_id, %{before: b, limit: limit}}) do
    q
    |> where([satisfaction: s], s.id <= ^b)
    |> filter(limit: limit + 2)
  end

  def filter(q, {:paginate_id, %{limit: limit}}),
    do: filter(q, limit: limit + 1)

  def filter(q, other_filter), do: ValueFlows.Util.common_filters(q, other_filter)
end
