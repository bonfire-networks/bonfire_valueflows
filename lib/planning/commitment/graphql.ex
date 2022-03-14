if Code.ensure_loaded?(Bonfire.API.GraphQL) do
defmodule ValueFlows.Planning.Commitment.GraphQL do
  import Bonfire.Common.Config, only: [repo: 0]

  alias Bonfire.API.{GraphQL, GraphQL.ResolveField}
  alias ValueFlows.Planning.{Commitment.Commitments, Satisfaction.Satisfactions}

  def commitment(%{id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_commitment,
      context: id,
      info: info
    })
  end

  def commitments_filtered(%{filter: filts} = args, _info) when is_map(filts) do
    limit = Map.get(args, :limit, 10)
    offset = Map.get(args, :start, 0)
    filts = Enum.reduce(filts, [limit: limit, offset: offset], &filter/2)
    Commitments.many([:default] ++ filts)
  end

  def commitments_filtered(args, _) do
    Commitments.many([
      :default,
      limit: Map.get(args, :limit, 10),
      offset: Map.get(args, :start, 0)
    ])
  end

  defp filter({:search_string, text}, acc) when is_binary(text),
    do: Keyword.put(acc, :search, text)

  defp filter({:action, id}, acc) when is_binary(id),
    do: Keyword.put(acc, :action_id, id)

  # TODO: startDate and endDate filters

  defp filter({:finished, finished?}, acc) when is_boolean(finished?),
    do: Keyword.put(acc, :status, finished? && :closed || :open)

  defp filter(_, acc),
    do: acc

  def fetch_commitment(info, id),
    do: Commitments.by_id(id, GraphQL.current_user(info))

  def fetch_resource_inventoried_as_edge(%{resource_inventoried_as_id: id} = comm, _, _)
      when is_binary(id) do
    comm = repo().preload(comm, :resource_inventoried_as)
    {:ok, comm.resource_inventoried_as}
  end

  def fetch_resource_inventoried_as_edge(_, _, _),
    do: {:ok, nil}

  def fetch_input_of_edge(%{input_of_id: id} = comm, _, _) when is_binary(id) do
    comm = repo().preload(comm, :input_of)
    {:ok, comm.input_of}
  end

  def fetch_input_of_edge(_, _, _),
    do: {:ok, nil}

  def fetch_output_of_edge(%{output_of_id: id} = comm, _, _) when is_binary(id) do
    comm = repo().preload(comm, :output_of)
    {:ok, comm.output_of}
  end

  def fetch_output_of_edge(_, _, _),
    do: {:ok, nil}

  def fetch_created(%{id: id}, _, _) when is_binary(id),
    do: Pointers.ULID.timestamp(id)

  def fetch_created(_, _, _),
    do: {:ok, nil}

  def fetch_satisfies_edge(%{id: id}, _, _) when is_binary(id),
    do: Satisfactions.many([:default, satisfied_by_id: id])

  def fetch_satisfies_edge(_, _, _),
    do: {:ok, nil}

  def create_commitment(%{commitment: attrs}, info) do
    repo().transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, comm} <- Commitments.create(user, attrs) do
        {:ok, %{commitment: comm}}
      end
    end)
  end

  def update_commitment(%{commitment: %{id: id} = changes}, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
         {:ok, comm} <- Commitments.update(user, id, changes) do
      {:ok, %{commitment: comm}}
    end
  end

  def delete_commitment(%{id: id}, info) do
    repo().transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, _} <- Commitments.soft_delete(user, id) do
        {:ok, true}
      end
    end)
  end
end
end
