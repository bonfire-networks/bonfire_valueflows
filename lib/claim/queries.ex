# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Claim.Queries do
  import Bonfire.Repo.Common, only: [match_admin: 0]
  import Ecto.Query


  alias ValueFlows.Claim

  def query(Claim) do
    from(c in Claim, as: :claim)
  end

  def query(filters), do: query(Claim, filters)

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
    join(q, jq, [claim: c], c2 in assoc(c, :context), as: :context)
  end

  def filter(q, filters) when is_list(filters) do
    Enum.reduce(filters, q, &filter(&2, &1))
  end

  def filter(q, {:join, {join, qual}}), do: join_to(q, join, qual)
  def filter(q, {:join, join}), do: join_to(q, join)

  ## by status

  def filter(q, :default) do
    filter(q, [:deleted])
  end

  def filter(q, :deleted) do
    where(q, [claim: c], is_nil(c.deleted_at))
  end

  def filter(q, :disabled) do
    where(q, [claim: c], is_nil(c.disabled_at))
  end

  def filter(q, :private) do
    where(q, [claim: c], not is_nil(c.published_at))
  end

  ## by user

  def filter(q, {:creator, match_admin()}), do: q

  def filter(q, {:creator, nil}) do
    filter(q, ~w(disabled private)a)
  end

  def filter(q, {:creator, %{id: user_id}}) do
    q
    |> where([claim: c], not is_nil(c.published_at) or c.creator_id == ^user_id)
    |> filter(~w(disabled)a)
  end

  ## by field values

  def filter(q, {:id, id}) when is_binary(id) do
    where(q, [claim: c], c.id == ^id)
  end

  def filter(q, {:id, ids}) when is_list(ids) do
    where(q, [claim: c], c.id in ^ids)
  end

  def filter(q, {:provider_id, id}) when is_binary(id) do
    where(q, [claim: c], c.provider_id == ^id)
  end

  def filter(q, {:provider_id, ids}) when is_list(ids) do
    where(q, [claim: c], c.provider_id in ^ids)
  end

  def filter(q, {:receiver_id, id}) when is_binary(id) do
    where(q, [claim: c], c.receiver_id == ^id)
  end

  def filter(q, {:receiver_id, ids}) when is_list(ids) do
    where(q, [claim: c], c.receiver_id in ^ids)
  end

  def filter(q, {:context_id, id}) when is_binary(id) do
    where(q, [claim: c], c.context_id == ^id)
  end

  def filter(q, {:context_id, ids}) when is_list(ids) do
    where(q, [claim: c], c.context_id in ^ids)
  end

  def filter(q, {:action_id, ids}) when is_list(ids) do
    where(q, [claim: c], c.action_id in ^ids)
  end

  def filter(q, {:action_id, id}) when is_binary(id) do
    where(q, [claim: c], c.action_id == ^id)
  end

  ## preloading

  def filter(q, {:preload, :all}) do
    preload(q, [
      :creator,
      :provider,
      :receiver,
      :resource_conforms_to,
      :resource_quantity,
      :effort_quantity,
      :context,
      :triggered_by,
    ])
  end
end
