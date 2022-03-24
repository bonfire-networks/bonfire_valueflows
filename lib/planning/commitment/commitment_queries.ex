# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Planning.Commitment.Queries do
  alias ValueFlows.Planning.Commitment

  import Ecto.Query
  import Geo.PostGIS
  import Where

  def query(Commitment),
    do: from(c in Commitment, as: :commitment)

  def query(:count),
    do: from(c in Commitment, as: :commitment)

  def query(filters),
    do: query(Commitment, filters)

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

  def join_to(q, :geolocation, jq),
    do: join(q, jq, [commitment: c], g in assoc(c, :at_location), as: :geolocation)

  # def join_to(q, :like_count, jq),
  #   do: join(q, jq, [commitment: c], g in assoc(c, :like_count), as: :like_count)

  def join_to(q, :tags, jq),
    do: join(q, jq, [commitment: c], t in assoc(c, :tags), as: :tags)

  def join_to(q, :effort_quantity, jq),
    do: join(q, jq, [commitment: c], q in assoc(c, :effort_quantity), as: :effort_quantity)

  def join_to(q, :resource_quantity, jq),
    do: join(q, jq, [commitment: c], q in assoc(c, :resource_quantity), as: :resource_quantity)


  # filter
  def filter(q, filters) when is_list(filters),
    do: Enum.reduce(filters, q, &filter(&2, &1))

  def filter(q, :default),
    do: filter(q, [:deleted, order: :default, preload: :quantities])

  def filter(q, :deleted),
    do: where(q, [commitment: c], is_nil(c.deleted_at))

  def filter(q, :deleted, true),
    do: where(q, [commitment: c], not is_nil(c.deleted_at))

  def filter(q, :disabled),
    do: where(q, [commitment: c], is_nil(c.disabled_at))

  def filter(q, :private),
    do: where(q, [commitment: c], not is_nil(c.published_at))

  def filter(q, {:status, :open}),
    do: where(q, [commitment: c], c.finished == false)

  def filter(q, {:status, :closed}),
    do: where(q, [commitment: c], c.finished == true)


  # search
  def filter(q, {:search, text}) when is_binary(text),
    do: where(q, [commitment: c], ilike(c.note, ^"%#{text}%"))


  # join
  def filter(q, {:join, {join, qual}}),
    do: join_to(q, join, qual)

  def filter(q, {:join, join}),
    do: join_to(q, join)


  # user
  def filter(q, {:user, %{id: user_id}}) do
    q
    |> where([commitment: c], not is_nil(c.published_at) or c.creator_id == ^user_id)
    |> filter(~w(disabled)a)
  end


  # field
  def filter(q, {:id, id}) when is_binary(id),
    do: where(q, [commitment: c], c.id == ^id)

  def filter(q, {:id, ids}) when is_list(ids),
    do: where(q, [commitment: c], c.id in ^ids)

  def filter(q, {:context_id, id}) when is_binary(id),
    do: where(q, [commitment: c], c.context_id == ^id)

  def filter(q, {:context_id, ids}) when is_list(ids),
    do: where(q, [commitment: c], c.context_id in ^ids)

  def filter(q, {:agent_id, id}) when is_binary(id),
    do: where(q, [commitment: c], c.provider_id == ^id or c.receiver_id == ^id)

  def filter(q, {:agent_id, ids}) when is_list(ids),
    do: where(q, [commitment: c], c.provider_id in ^ids or c.receiver_id in ^ids)

  def filter(q, {:provider_id, id}) when is_binary(id),
    do: where(q, [commitment: c], c.provider_id == ^id)

  def filter(q, {:provider_id, ids}) when is_list(ids),
    do: where(q, [commitment: c], c.provider_id in ^ids)

  def filter(q, {:receiver_id, id}) when is_binary(id),
    do: where(q, [commitment: c], c.receiver_id == ^id)

  def filter(q, {:receiver_id, ids}) when is_list(ids),
    do: where(q, [commitment: c], c.receiver_id in ^ids)

  def filter(q, {:action_id, ids}) when is_list(ids),
    do: where(q, [commitment: c], c.action_id in ^ids)

  def filter(q, {:action_id, id}) when is_binary(id),
    do: where(q, [commitment: c], c.action_id == ^id)

  def filter(q, {:at_location_id, at_location_id}) do
    q
    |> join_to(:geolocation)
    |> preload(:at_location)
    |> where([commitment: c], c.at_location_id == ^at_location_id)
  end

  def filter(q, {:near_point, geom_point, :distance_meters, meters}) do
    q
    |> join_to(:geolocation)
    |> preload(:at_location)
    |> where([commitment: c, geolocation: g], st_dwithin_in_meters(g.geom, ^geom_point, ^meters))
  end

  def filter(q, {:location_within, geom_point}) do
    q
    |> join_to(:geolocation)
    |> preload(:at_location)
    |> where([commitment: c, geolocation: g], st_within(g.geom, ^geom_point))
  end

  def filter(q, {:tag_ids, ids}) when is_list(ids) do
    q
    |> preload(:tags)
    |> join_to(:tags)
    |> group_by([commitment: c], c.id)
    |> having(
      [commitment: c, tags: t],
      fragment("? <@ array_agg(?)", type(^ids, {:array, Pointers.ULID}), t.id)
    )
  end

  def filter(q, {:tag_ids, tag_id}) when is_binary(tag_id),
    do: filter(q, {:tag_ids, [tag_id]})

  def filter(q, {:tag_id, tag_id}) when is_binary(tag_id),
    do: filter(q, {:tag_ids, [tag_id]})

  def filter(q, {:output_of_id, id}) when is_binary(id),
    do: where(q, [commitment: c], c.output_of_id == ^id)

  def filter(q, {:input_of_id, id}) when is_binary(id),
    do: where(q, [commitment: c], c.input_of_id == ^id)


  # order
  def filter(q, {:order, [desc: key]}) when is_atom(key),
    do: order_by(q, [commitment: c], desc: field(c, ^key))

  def filter(q, {:order, [asc: key]}) when is_atom(key),
    do: order_by(q, [commitment: c], asc: field(c, ^key))

  def filter(q, {:order, :default}),
    do: order_by(q, [commitment: c], [desc: c.has_beginning, desc: c.has_point_in_time, desc: c.has_end, desc: c.due, desc: c.updated_at, asc: c.id])

  def filter(q, {:order, :voted}),
    do: filter(q, order: [desc: :voted])

  # def filter(q, {:order, [desc: :voted]}) do
  #   q
  #   |> join_to(:like_count)
  #   |> preload(:like_count)
  #   |> order_by([commitment: c, like_count: lc], desc: lc.liker_count)
  # end

  def filter(q, {:order, key}),
    do: filter(q, order: [desc: key])


  # group and count
  def filter(q, {:group_count, key}) when is_atom(key),
    do: filter(q, group: key, count: key)

  def filter(q, {:group, key}) when is_atom(key),
    do: group_by(q, [commitment: c], field(c, ^key))

  def filter(q, {:count, key}) when is_atom(key),
    do: select(q, [commitment: c], {field(c, ^key), count(c.id)})

  def filter(q, {:preload, :all}) do
    q
    |> preload([
      :provider,
      :receiver,
      :input_of,
      :output_of,
      :creator,
      :context,
      :at_location,
      :resource_inventoried_as,
      :resource_conforms_to,
    ])
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
    |> where([commitment: c], c.id >= ^a)
    |> limit(^limit)
  end

  def filter(q, {:paginate_id, %{before: b, limit: limit}}) do
    q
    |> where([commitment: c], c.id <= ^b)
    |> filter(limit: limit + 2)
  end

  def filter(q, {:paginate_id, %{limit: limit}}),
    do: filter(q, limit: limit + 1)

  def filter(q, other_filter), do: ValueFlows.Util.common_filters(q, other_filter)

end
