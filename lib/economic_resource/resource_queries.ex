# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.EconomicResource.Queries do
  alias ValueFlows.{EconomicResource, EconomicEvent}
  # alias ValueFlows.EconomicResources

  import Bonfire.Repo.Common, only: [match_admin: 0]
  import Ecto.Query
  import Geo.PostGIS

  def query(EconomicResource) do
    from(c in EconomicResource, as: :resource)
  end

  def query(:count) do
    from(c in EconomicResource, as: :resource)
  end

  def query(filters), do: query(EconomicResource, filters)

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
    join(q, jq, [resource: c], c2 in assoc(c, :context), as: :context)
  end

  def join_to(q, {:event_output, output_of_id}, _jq) do
    join(q, :inner, [resource: r],
      e in EconomicEvent,
      as: :event,
      on: e.resource_inventoried_as_id == r.id and e.output_of_id == ^output_of_id
    )
  end

  def join_to(q, {:event_input, input_of_id}, _jq) do
    join(q, :inner, [resource: r],
      e in EconomicEvent,
      as: :event,
      on: e.resource_inventoried_as_id == r.id and e.input_of_id == ^input_of_id
    )
  end

  def join_to(q, :geolocation, jq) do
    join(q, jq, [resource: c], g in assoc(c, :current_location), as: :geolocation)
  end

  def join_to(q, :tags, jq) do
    join(q, jq, [resource: c], t in assoc(c, :tags), as: :tags)
  end

  def join_to(q, :unit_of_effort, jq) do
    join(q, jq, [resource: c], t in assoc(c, :unit_of_effort), as: :unit_of_effort)
  end

  def join_to(q, :contained_in, jq) do
    join(q, jq, [resource: c], t in assoc(c, :contained_in), as: :contained_in)
  end

  # def join_to(q, :primary_accountable, jq) do
  #   join q, jq, [follow: f], c in assoc(f, :primary_accountable), as: :pointer
  # end

  # def join_to(q, :receiver, jq) do
  #   join q, jq, [follow: f], c in assoc(f, :receiver), as: :pointer
  # end

  # def join_to(q, :follower_count, jq) do
  #   join q, jq, [resource: c],
  #     f in FollowerCount, on: c.id == f.context_id,
  #     as: :follower_count
  # end

  ### filter/2

  ## by many

  def filter(q, filters) when is_list(filters) do
    Enum.reduce(filters, q, &filter(&2, &1))
  end

  ## by preset

  def filter(q, :default) do
    #filter(q, [:deleted])
    filter q, [
      :deleted,
      # FIXME: use hydration
      # preload: :primary_accountable,
      # preload: :unit_of_effort,
    ]
  end

  def filter(q, :offer) do
    where(q, [resource: c], is_nil(c.receiver_id))
  end

  def filter(q, :need) do
    where(q, [resource: c], is_nil(c.primary_accountable_id))
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
    |> where([resource: c], not is_nil(c.published_at) or c.creator_id == ^user_id)
    |> filter(~w(disabled)a)
  end

  ## by status

  def filter(q, :deleted) do
    where(q, [resource: c], is_nil(c.deleted_at))
  end

  def filter(q, :disabled) do
    where(q, [resource: c], is_nil(c.disabled_at))
  end

  def filter(q, :private) do
    where(q, [resource: c], not is_nil(c.published_at))
  end

  ## by field values

  def filter(q, {:cursor, [count, id]})
      when is_integer(count) and is_binary(id) do
    where(
      q,
      [resource: c, follower_count: fc],
      (fc.count == ^count and c.id >= ^id) or fc.count > ^count
    )
  end

  def filter(q, {:cursor, [count, id]})
      when is_integer(count) and is_binary(id) do
    where(
      q,
      [resource: c, follower_count: fc],
      (fc.count == ^count and c.id <= ^id) or fc.count < ^count
    )
  end

  def filter(q, {:id, id}) when is_binary(id) do
    where(q, [resource: c], c.id == ^id)
  end

  def filter(q, {:id, ids}) when is_list(ids) do
    where(q, [resource: c], c.id in ^ids)
  end

  def filter(q, {:context_id, id}) when is_binary(id) do
    where(q, [resource: c], c.context_id == ^id)
  end

  def filter(q, {:context_id, ids}) when is_list(ids) do
    where(q, [resource: c], c.context_id in ^ids)
  end

  def filter(q, {:agent_id, id}) when is_binary(id) do
    where(q, [resource: c], c.primary_accountable_id == ^id or c.creator_id == ^id)
  end

  def filter(q, {:agent_id, ids}) when is_list(ids) do
    where(q, [resource: c], c.primary_accountable_id in ^ids or c.creator_id in ^ids)
  end

  def filter(q, {:primary_accountable_id, id}) when is_binary(id) do
    where(q, [resource: c], c.primary_accountable_id == ^id)
  end

  def filter(q, {:primary_accountable_id, ids}) when is_list(ids) do
    where(q, [resource: c], c.primary_accountable_id in ^ids)
  end

  def filter(q, {:receiver_id, id}) when is_binary(id) do
    where(q, [resource: c], c.receiver_id == ^id)
  end

  def filter(q, {:receiver_id, ids}) when is_list(ids) do
    where(q, [resource: c], c.receiver_id in ^ids)
  end

  def filter(q, {:state_id, ids}) when is_list(ids) do
    where(q, [resource: c], c.state_id in ^ids)
  end

  def filter(q, {:state_id, id}) when is_binary(id) do
    where(q, [resource: c], c.state_id == ^id)
  end

  def filter(q, {:tracking_identifier, id}) when is_binary(id) do
    where(q, [resource: c], c.tracking_identifier == ^id)
  end

  def filter(q, {:tracking_identifier, ids}) when is_list(ids) do
    where(q, [resource: c], c.tracking_identifier in ^ids)
  end


  def filter(q, {:current_location_id, current_location_ids}) when is_list(current_location_ids) do
    q
    |> join_to(:geolocation)
    |> preload(:current_location)
    |> where([resource: c], c.current_location_id in ^current_location_ids)
  end

  def filter(q, {:current_location_id, current_location_id}) when is_binary(current_location_id) do
    q
    |> join_to(:geolocation)
    |> preload(:current_location)
    |> where([resource: c], c.current_location_id == ^current_location_id)
  end

  def filter(q, {:near_point, geom_point, :distance_meters, meters}) do
    q
    |> join_to(:geolocation)
    |> preload(:current_location)
    |> where([resource: c, geolocation: g], st_dwithin_in_meters(g.geom, ^geom_point, ^meters))
  end

  def filter(q, {:location_within, geom_point}) do
    q
    |> join_to(:geolocation)
    |> preload(:current_location)
    |> where([resource: c, geolocation: g], st_within(g.geom, ^geom_point))
  end

  def filter(q, {:tag_ids, ids}) when is_list(ids) do
    q
    |> preload(:tags)
    |> join_to(:tags)
    |> group_by([resource: c], c.id)
    |> having(
      [resource: c, tags: t],
      fragment("? <@ array_agg(?)", type(^ids, {:array, Pointers.ULID}), t.id)
    )
  end

  def filter(q, {:tag_ids, id}) when is_binary(id) do
    filter(q, {:tag_ids, [id]})
  end

  def filter(q, {:tag_id, id}) when is_binary(id) do
    filter(q, {:tag_ids, [id]})
  end

  def filter(q, {:search, text}) when is_binary(text) do
    where(q, [resource: c],
    ilike(c.name, ^"%#{text}%")
    or ilike(c.note, ^"%#{text}%")
    )
  end

  def filter(q, {:autocomplete, text}) when is_binary(text) do
    q
    |> select([resource: c],
      struct(c, [:id, :name])
    )
    |> where([resource: c],
      ilike(c.name, ^"#{text}%")
      or ilike(c.name, ^"% #{text}%")
      or ilike(c.note, ^"#{text}%")
      or ilike(c.note, ^"% #{text}%")
    )
  end

  ## by ordering

  def filter(q, {:order, :id}) do
    filter(q, order: [desc: :id])
  end

  def filter(q, {:order, [desc: :id]}) do
    order_by(q, [resource: c, id: id],
      desc: coalesce(id.count, 0),
      desc: c.id
    )
  end

  # grouping and counting

  def filter(q, {:group_count, key}) when is_atom(key) do
    filter(q, group: key, count: key)
  end

  def filter(q, {:group, key}) when is_atom(key) do
    group_by(q, [resource: c], field(c, ^key))
  end

  def filter(q, {:count, key}) when is_atom(key) do
    select(q, [resource: c], {field(c, ^key), count(c.id)})
  end

  def filter(q, {:preload, :all}) do
    preload(q, [
      :accounting_quantity,
      :onhand_quantity,
      :unit_of_effort,
      :primary_accountable,
      :current_location,
      :contained_in,
      :conforms_to,
      :image
    ])
  end

  def filter(q, {:preload, :primary_accountable}) do
    preload(q, :primary_accountable)
  end

  def filter(q, {:preload, :receiver}) do
    preload(q, [pointer: p], receiver: p)
  end

  def filter(q, {:preload, :unit_of_effort}) do
    q
    |> join_to(:unit_of_effort)
    |> preload([unit_of_effort: u], unit_of_effort: u)
  end

  def filter(q, {:preload, :current_location}) do
    q
    |> join_to(:geolocation)
    |> preload(:current_location)

    # preload(q, [geolocation: g], current_location: g)
  end

  def filter(q, {:preload, :contained_in}) do
    q
    |> join_to(:contained_in)
    |> preload([contained_in: cin], contained_in: cin)
  end

  # pagination

  def filter(q, {:limit, limit}) do
    limit(q, ^limit)
  end

  def filter(q, {:paginate_id, %{after: a, limit: limit}}) do
    limit = limit + 2

    q
    |> where([resource: c], c.id >= ^a)
    |> limit(^limit)
  end

  def filter(q, {:paginate_id, %{before: b, limit: limit}}) do
    q
    |> where([resource: c], c.id <= ^b)
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
  #     [resource: c,  follower_count: fc],
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
