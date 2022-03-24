# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Knowledge.ProcessSpecification.Queries do
  alias ValueFlows.Knowledge.ProcessSpecification
  # alias ValueFlows.Knowledge.ProcessSpecifications

  import Bonfire.Repo.Common, only: [match_admin: 0]
  import Ecto.Query
  # import Geo.PostGIS
  import Where

  def query(ProcessSpecification) do
    from(c in ProcessSpecification, as: :process_spec)
  end

  def query(:count) do
    from(c in ProcessSpecification, as: :process_spec)
  end

  def query(filters), do: query(ProcessSpecification, filters)

  def query(q, filters), do: filter(query(q), filters)

  def queries(query, _page_opts, base_filters, data_filters, count_filters) do
    base_q = query(query, base_filters)
    data_q = filter(base_q, data_filters)
    count_q = filter(base_q, count_filters)
    {data_q, count_q}
  end

  def join_to(q, spec, join_qualifier \\ :left)

  def join_to(q, specs, jq) when is_list(specs) do
    Enum.reduce(specs, q, &join_to(&2, &1, jq))
  end

  def join_to(q, :context, jq) do
    join(q, jq, [process_spec: c], c2 in assoc(c, :context), as: :context)
  end

  def join_to(q, :tags, jq) do
    join(q, jq, [process_spec: c], t in assoc(c, :tags), as: :tags)
  end

  ### filter/2

  ## by many

  def filter(q, filters) when is_list(filters) do
    Enum.reduce(filters, q, &filter(&2, &1))
  end

  ## by preset

  def filter(q, :default) do
    filter(q, [:deleted])
    # filter q, [:deleted, {:preload, :provider}, {:preload, :receiver}]
  end

  ## by join

  def filter(q, {:join, {join, qual}}), do: join_to(q, join, qual)
  def filter(q, {:join, join}), do: join_to(q, join)

  ## by user

  def filter(q, {:user, match_admin()}), do: q

  def filter(q, {:user, nil}) do
    filter(q, ~w(disabled private)a)
  end

  def filter(q, {:user, %{id: user_id}}) do
    q
    |> where([process_spec: c], not is_nil(c.published_at) or c.creator_id == ^user_id)
    |> filter(~w(disabled)a)
  end

  ## by status

  def filter(q, :deleted) do
    where(q, [process_spec: c], is_nil(c.deleted_at))
  end

  def filter(q, :disabled) do
    where(q, [process_spec: c], is_nil(c.disabled_at))
  end

  def filter(q, :private) do
    where(q, [process_spec: c], not is_nil(c.published_at))
  end

  ## by field values

  def filter(q, {:id, id}) when is_binary(id) do
    where(q, [process_spec: c], c.id == ^id)
  end

  def filter(q, {:id, ids}) when is_list(ids) do
    where(q, [process_spec: c], c.id in ^ids)
  end

  def filter(q, {:context_id, id}) when is_binary(id) do
    where(q, [process_spec: c], c.context_id == ^id)
  end

  def filter(q, {:context_id, ids}) when is_list(ids) do
    where(q, [process_spec: c], c.context_id in ^ids)
  end

  def filter(q, {:tag_ids, ids}) when is_list(ids) do
    q
    |> preload(:tags)
    |> join_to(:tags)
    |> group_by([process_spec: c], c.id)
    |> having(
      [process_spec: c, tags: t],
      fragment("? <@ array_agg(?)", type(^ids, {:array, Pointers.ULID}), t.id)
    )
  end

  def filter(q, {:tag_ids, id}) when is_binary(id) do
    filter(q, {:tag_ids, [id]})
  end

  def filter(q, {:tag_id, id}) when is_binary(id) do
    filter(q, {:tag_ids, [id]})
  end

  ## by ordering

  def filter(q, {:order, :id}) do
    filter(q, order: [desc: :id])
  end

  def filter(q, {:order, [desc: :id]}) do
    order_by(q, [process_spec: c, id: id],
      desc: coalesce(id.count, 0),
      desc: c.id
    )
  end

  # grouping and counting

  def filter(q, {:group_count, key}) when is_atom(key) do
    filter(q, group: key, count: key)
  end

  def filter(q, {:group, key}) when is_atom(key) do
    group_by(q, [process_spec: c], field(c, ^key))
  end

  def filter(q, {:count, key}) when is_atom(key) do
    select(q, [process_spec: c], {field(c, ^key), count(c.id)})
  end

  # pagination

  def filter(q, {:limit, limit}) do
    limit(q, ^limit)
  end

  def filter(q, {:paginate_id, %{after: a, limit: limit}}) do
    limit = limit + 2

    q
    |> where([process_spec: c], c.id >= ^a)
    |> limit(^limit)
  end

  def filter(q, {:paginate_id, %{before: b, limit: limit}}) do
    q
    |> where([process_spec: c], c.id <= ^b)
    |> filter(limit: limit + 2)
  end

  def filter(q, {:paginate_id, %{limit: limit}}) do
    filter(q, limit: limit + 1)
  end

  # def filter(q, {:page, [desc: [followers: page_opts]]}) do
  #   q
  #   |> filter(join: :follower_count, order: [desc: :followers])
  #   |> page(page_opts, [desc: :followers])
  #   |> select(
  #     [process_spec: c,  follower_count: fc],
  #     %{c | follower_count: coalesce(fc.count, 0)}
  #   )
  # end

  # defp page(q, %{after: cursor, limit: limit}, [desc: :followers]) do
  #   filter q, cursor: [followers: {:lte, cursor}], limit: limit + 2
  # end

  # defp page(q, %{before: cursor, limit: limit}, [desc: :followers]) do
  #   filter q, cursor: [followers: {:gte, cursor}], limit: limit + 2
  # end

  # defp page(q, %{limit: limit}, _), do: filter(q, limit: limit + 1)

  def filter(q, other_filter), do: ValueFlows.Util.common_filters(q, other_filter)
end
