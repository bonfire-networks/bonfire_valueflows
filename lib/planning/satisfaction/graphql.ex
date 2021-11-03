if Code.ensure_loaded?(Bonfire.GraphQL) do
defmodule ValueFlows.Planning.Satisfaction.GraphQL do
  import Bonfire.GraphQL, only: [current_user_or_not_logged_in: 1]
  import Bonfire.Common.Config, only: [repo: 0]

  alias ValueFlows.Planning.Satisfaction.Satisfactions
  alias ValueFlows.Planning.Commitment
  alias ValueFlows.EconomicEvent

  def satisfaction(%{id: id}, info) do
    alias Bonfire.GraphQL.ResolveField

    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_satisfaction,
      context: id,
      info: info
    })
  end

  def satisfactions_filtered(args, _info) do
    limit = Map.get(args, :limit, 10)
    offset = Map.get(args, :start, 0)
    Satisfactions.many([:default, limit: limit, offset: offset])
  end

  def fetch_satisfaction(info, id) do
    import Bonfire.GraphQL, only: [current_user: 1]

    Satisfactions.by_id(id, current_user(info))
  end

  def fetch_satisfies_edge(%{satisfies_id: id} = satis, _, _) when is_binary(id) do
    satis = repo().preload(satis, :satisfies)
    {:ok, Map.get(satis, :satisfies, nil)}
  end

  def fetch_satisfies_edge(_, _, _),
    do: {:ok, nil}

  def fetch_satisfied_by_edge(%{satisfied_by_id: id} = satis, _, info) when is_binary(id) do
    # XXX: This is a hack where I use the fact that the field `created`
    # is only available in Commitments.  A proper fix would be to use
    # Pointers correctly, I think.

    import Commitment.GraphQL, only: [fetch_commitment: 2]
    import EconomicEvent.GraphQL, only: [fetch_event: 2]

    satis = repo().preload(satis, :satisfied_by)

    maybe_satis_by =
      case satis.satisfied_by do
        %{created: _} -> fetch_commitment(info, id)
        _ -> fetch_event(info, id)
      end

    with {:ok, satis_by} <- maybe_satis_by,
         do: {:ok, satis_by}
  end

  def fetch_satisfied_by_edge(_, _, _),
    do: {:ok, nil}

  def event_or_commitment_resolve_type(%EconomicEvent{}, _),
    do: :economic_event

  def event_or_commitment_resolve_type(%Commitment{}, _),
    do: :commitment

  def event_or_commitment_resolve_type(_, _),
    do: nil

  def create(%{satisfaction: attrs}, info) do
    repo().transact_with(fn ->
      with {:ok, user} <- current_user_or_not_logged_in(info),
           {:ok, satis} <- Satisfactions.create(user, attrs) do
        {:ok, %{satisfaction: satis}}
      end
    end)
  end

  def update(%{satisfaction: %{id: id} = changes}, info) do
    with {:ok, user} <- current_user_or_not_logged_in(info),
         {:ok, satis} <- Satisfactions.update(user, id, changes) do
      {:ok, %{satisfaction: satis}}
    end
  end

  def delete(%{id: id}, info) do
    with {:ok, user} <- current_user_or_not_logged_in(info),
         {:ok, _} <- Satisfactions.soft_delete(user, id) do
      {:ok, true}
    end
  end
end
end
