# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Planning.Intent.Queries do
  alias ValueFlows.Planning.Intent
  # alias ValueFlows.Planning.Intents
  @user Bonfire.Common.Config.get_ext(:bonfire_valueflows, :user_schema)
  import Bonfire.Repo.Query, only: [match_admin: 0]
  import Ecto.Query
  import Geo.PostGIS

  def query(Intent) do
    from(c in Intent, as: :intent)
  end

  def query(:count) do
    from(c in Intent, as: :intent)
  end

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

  def join_to(q, :geolocation, jq) do
    join(q, jq, [intent: c], g in assoc(c, :at_location), as: :geolocation)
  end

  def join_to(q, :tags, jq) do
    join(q, jq, [intent: c], t in assoc(c, :tags), as: :tags)
  end

  def join_to(q, :effort_quantity, jq) do
    join(q, jq, [intent: c], q in assoc(c, :effort_quantity), as: :effort_quantity)
  end

  def join_to(q, :resource_quantity, jq) do
    join(q, jq, [intent: c], q in assoc(c, :resource_quantity), as: :resource_quantity)
  end

  def join_to(q, :available_quantity, jq) do
    join(q, jq, [intent: c], q in assoc(c, :available_quantity), as: :available_quantity)
  end

  ### filter/2

  ## by many

  def filter(q, filters) when is_list(filters) do
    Enum.reduce(filters, q, &filter(&2, &1))
  end

  ## by preset

  def filter(q, :default) do
    filter(q, [:deleted, preload: :quantities])
  end

  def filter(q, :offer) do
    where(q, [intent: c], is_nil(c.receiver_id))
  end

  def filter(q, :need) do
    where(q, [intent: c], is_nil(c.provider_id))
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
    |> where([intent: c], not is_nil(c.published_at) or c.creator_id == ^user_id)
    |> filter(~w(disabled)a)
  end

  ## by status

  def filter(q, :deleted) do
    where(q, [intent: c], is_nil(c.deleted_at))
  end

  def filter(q, :disabled) do
    where(q, [intent: c], is_nil(c.disabled_at))
  end

  def filter(q, :private) do
    where(q, [intent: c], not is_nil(c.published_at))
  end

  ## by field values

  def filter(q, {:cursor, [count, id]})
      when is_integer(count) and is_binary(id) do
    where(
      q,
      [intent: c, follower_count: fc],
      (fc.count == ^count and c.id >= ^id) or fc.count > ^count
    )
  end

  def filter(q, {:cursor, [count, id]})
      when is_integer(count) and is_binary(id) do
    where(
      q,
      [intent: c, follower_count: fc],
      (fc.count == ^count and c.id <= ^id) or fc.count < ^count
    )
  end

  def filter(q, {:id, id}) when is_binary(id) do
    where(q, [intent: c], c.id == ^id)
  end

  def filter(q, {:id, ids}) when is_list(ids) do
    where(q, [intent: c], c.id in ^ids)
  end

  def filter(q, {:context_id, id}) when is_binary(id) do
    where(q, [intent: c], c.context_id == ^id)
  end

  def filter(q, {:context_id, ids}) when is_list(ids) do
    where(q, [intent: c], c.context_id in ^ids)
  end

  def filter(q, {:agent_id, id}) when is_binary(id) do
    where(q, [intent: c], c.provider_id == ^id or c.receiver_id == ^id)
  end

  def filter(q, {:agent_id, ids}) when is_list(ids) do
    where(q, [intent: c], c.provider_id in ^ids or c.receiver_id in ^ids)
  end

  def filter(q, {:provider_id, id}) when is_binary(id) do
    where(q, [intent: c], c.provider_id == ^id)
  end

  def filter(q, {:provider_id, ids}) when is_list(ids) do
    where(q, [intent: c], c.provider_id in ^ids)
  end

  def filter(q, {:receiver_id, id}) when is_binary(id) do
    where(q, [intent: c], c.receiver_id == ^id)
  end

  def filter(q, {:receiver_id, ids}) when is_list(ids) do
    where(q, [intent: c], c.receiver_id in ^ids)
  end

  def filter(q, {:action_id, ids}) when is_list(ids) do
    where(q, [intent: c], c.action_id in ^ids)
  end

  def filter(q, {:action_id, id}) when is_binary(id) do
    where(q, [intent: c], c.action_id == ^id)
  end

  def filter(q, {:at_location_id, at_location_id}) do
    q
    |> join_to(:geolocation)
    |> preload(:at_location)
    |> where([intent: c], c.at_location_id == ^at_location_id)
  end

  def filter(q, {:near_point, geom_point, :distance_meters, meters}) do
    q
    |> join_to(:geolocation)
    |> preload(:at_location)
    |> where([intent: c, geolocation: g], st_dwithin_in_meters(g.geom, ^geom_point, ^meters))
  end

  def filter(q, {:location_within, geom_point}) do
    q
    |> join_to(:geolocation)
    |> preload(:at_location)
    |> where([intent: c, geolocation: g], st_within(g.geom, ^geom_point))
  end

  def filter(q, {:tag_ids, ids}) when is_list(ids) do
    q
    |> preload(:tags)
    |> join_to(:tags)
    |> group_by([intent: c], c.id)
    |> having(
      [intent: c, tags: t],
      fragment("? <@ array_agg(?)", type(^ids, {:array, Ecto.ULID}), t.id)
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
    order_by(q, [intent: c, id: id],
      desc: coalesce(id.count, 0),
      desc: c.id
    )
  end

  # grouping and counting

  def filter(q, {:group_count, key}) when is_atom(key) do
    filter(q, group: key, count: key)
  end

  def filter(q, {:group, key}) when is_atom(key) do
    group_by(q, [intent: c], field(c, ^key))
  end

  def filter(q, {:count, key}) when is_atom(key) do
    select(q, [intent: c], {field(c, ^key), count(c.id)})
  end

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
    |> join_to([:available_quantity, :effort_quantity, :resource_quantity])
    |> preload([:available_quantity, :effort_quantity, :resource_quantity])
  end

  # pagination

  def filter(q, {:limit, limit}) do
    limit(q, ^limit)
  end

  def filter(q, {:paginate_id, %{after: a, limit: limit}}) do
    limit = limit + 2

    q
    |> where([intent: c], c.id >= ^a)
    |> limit(^limit)
  end

  def filter(q, {:paginate_id, %{before: b, limit: limit}}) do
    q
    |> where([intent: c], c.id <= ^b)
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
  #     [intent: c,  follower_count: fc],
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
end
