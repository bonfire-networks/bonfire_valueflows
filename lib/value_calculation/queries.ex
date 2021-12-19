# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.ValueCalculation.Queries do
  import Bonfire.Repo.Common, only: [match_admin: 0]
  import Ecto.Query

  alias ValueFlows.ValueCalculation
  alias ValueFlows.EconomicEvent

  def query(ValueCalculation) do
    from(vc in ValueCalculation, as: :value_calculation)
  end

  def query(filters), do: query(ValueCalculation, filters)

  def query(q, filters), do: filter(query(q), filters)

  def join_to(q, spec, join_qualifier \\ :left)

  def join_to(q, specs, jq) when is_list(specs) do
    Enum.reduce(specs, q, &join_to(&2, &1, jq))
  end

  def join_to(q, :context, jq) do
    join(q, jq, [claim: c], c2 in assoc(c, :context), as: :context)
  end

  def filter(q, filters) when is_list(filters) do
    Enum.reduce(filters, q, &filter(&2, &1))
  end

  ## by status

  def filter(q, :default) do
    filter(q, ~w(deleted)a)
  end

  def filter(q, :deleted) do
    where(q, [value_calculation: vc], is_nil(vc.deleted_at))
  end

  ## by user
  def filter(q, {:creator, match_admin()}), do: q

  def filter(q, {:creator, nil}) do
    q
    |> filter(~w(deleted)a)
  end

  def filter(q, {:creator, %{id: user_id}}) do
    q
    |> where([value_calculation: vc], vc.creator_id == ^user_id)
    |> filter(~w(deleted)a)
  end

  ## by field values

  def filter(q, {:cursor, [count, id]})
      when is_integer(count) and is_binary(id) do
    where(
      q,
      [value_calculation: vc, follower_count: fc],
      (fc.count == ^count and vc.id >= ^id) or fc.count > ^count
    )
  end

  def filter(q, {:id, id}) when is_binary(id) do
    where(q, [value_calculation: vc], vc.id == ^id)
  end

  def filter(q, {:id, ids}) when is_list(ids) do
    where(q, [value_calculation: vc], vc.id in ^ids)
  end

  def filter(q, {:context_id, id}) when is_binary(id) do
    where(q, [value_calculation: vc], vc.context_id == ^id)
  end

  def filter(q, {:context_id, ids}) when is_list(ids) do
    where(q, [value_calculation: vc], vc.context_id in ^ids)
  end

  def filter(q, {:action_id, id}) when is_binary(id) do
    where(q, [value_calculation: vc], vc.action_id == ^id)
  end

  def filter(q, {:action_id, ids}) when is_list(ids) do
    where(q, [value_calculation: vc], vc.action_id in ^ids)
  end

  def filter(q, {:resource_conforms_to_id, id}) when is_binary(id) do
    where(q, [value_calculation: vc], vc.resource_conforms_to_id == ^id)
  end

  def filter(q, {:resource_conforms_to_id, ids}) when is_list(ids) do
    where(q, [value_calculation: vc], vc.resource_conforms_to_id in ^ids)
  end

  ## context-based searches

  def filter(q, {:event, %{action_id: action_id, resource_conforms_to_id: resource_conforms_to_id}}) do
    q = filter(q, action_id: action_id)

    if resource_conforms_to_id do
      filter(q, resource_conforms_to_id: resource_conforms_to_id)
    else
      q
    end
  end

  def filter(q, {:event, %{action_id: action_id}}) do
    filter(q, action_id: action_id)
  end

  ## by ordering

  def filter(q, {:order, :id}) do
    filter(q, order: [desc: :id])
  end

  def filter(q, {:order, [desc: :id]}) do
    order_by(q, [value_calculation: vc, id: id],
      desc: coalesce(id.count, 0),
      desc: vc.id
    )
  end

  ## grouping and counting

  def filter(q, {:group_count, key}) when is_atom(key) do
    filter(q, group: key, count: key)
  end

  def filter(q, {:group, key}) when is_atom(key) do
    group_by(q, [value_calculation: vc], field(vc, ^key))
  end

  def filter(q, {:count, key}) when is_atom(key) do
    select(q, [value_calculation: vc], {field(vc, ^key), count(vc.id)})
  end

  ## pagination

  def filter(q, {:limit, limit}) do
    limit(q, ^limit)
  end

  def filter(q, {:paginate_id, %{after: a, limit: limit}}) do
    limit = limit + 2

    q
    |> where([value_calculation: vc], vc.id >= ^a)
    |> limit(^limit)
  end

  def filter(q, {:paginate_id, %{before: b, limit: limit}}) do
    q
    |> where([value_calculation: vc], vc.id <= ^b)
    |> filter(limit: limit + 2)
  end

  def filter(q, {:paginate_id, %{limit: limit}}) do
    filter(q, limit: limit + 1)
  end

  ## preloading

  def filter(q, {:preload, :all}) do
    preload(q, [
      :creator,
      :context,
      :value_unit,
      :resource_conforms_to,
      :value_resource_conforms_to,
    ])
  end
end
