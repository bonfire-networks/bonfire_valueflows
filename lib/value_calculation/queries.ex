# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.ValueCalculation.Queries do
  import Bonfire.Repo.Query, only: [match_admin: 0]
  import Ecto.Query

  alias ValueFlows.ValueCalculation

  def query(ValueCalculation) do
    from(vc in ValueCalculation, as: :value_calculation)
  end

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

  ## by user
  def filter(q, {:user, match_admin()}), do: q

  def filter(q, {:user, nil}) do
    q
  end

  def filter(q, {:user, %{id: user_id}}) do
    q
    |> where([value_calculation: vc], not is_nil(vc.published_at) or vc.creator_id == ^user_id)
  end

  ## by field values

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

  ## preloading

  def filter(q, {:preload, :all}) do
    preload(q, [
      :creator,
      :context,
      :value_unit,
    ])
  end
end
