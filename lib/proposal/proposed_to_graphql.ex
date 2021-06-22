if Code.ensure_loaded?(Bonfire.GraphQL) do
defmodule ValueFlows.Proposal.ProposedToGraphQL do
  use Absinthe.Schema.Notation

  alias Bonfire.GraphQL
  alias Bonfire.Common.Pointers
  alias ValueFlows.Proposal.Proposals

  alias Bonfire.GraphQL.ResolveField

  import Bonfire.Common.Config, only: [repo: 0]


  def proposed_to(%{id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_proposed_to,
      context: id,
      info: info
    })
  end

  def fetch_proposed_to(_info, id) do
    Proposals.one_proposed_to([:default, id: id])
  end

  def published_to_edge(%{id: id}, _, _info) when not is_nil(id) do
    Proposals.many_proposed_to([:default, proposed_id: id])
  end
  def published_to_edge(_, _, _info) do
    {:ok, nil}
  end

  def proposed_to_agent(%{proposed_to_id: id}, _, _info) when not is_nil(id) do
    {:ok, ValueFlows.Agent.Agents.agent(id, nil)}
  end
  def proposed_to_agent(_, _, _info) do
    {:ok, nil}
  end


  def fetch_proposed_edge(%{proposed_id: id} = thing, _, _)
      when is_binary(id) do
    thing = repo().preload(thing, :proposed)
    {:ok, Map.get(thing, :proposed)}
  end

  def fetch_proposed_edge(_, _, _) do
    {:ok, nil}
  end


  def propose_to(%{proposed_to: agent_id, proposed: proposed_id}, info) do
    with :ok <- GraphQL.is_authenticated(info),
         {:ok, pointer} <- Pointers.one(id: agent_id),
        #  :ok <- validate_context(pointer),
         agent = Pointers.follow!(pointer),
         {:ok, proposed} <- ValueFlows.Proposal.GraphQL.proposal(%{id: proposed_id}, info),
         {:ok, proposed_to} <- Proposals.propose_to(agent, proposed) do
      {:ok, %{proposed_to: %{proposed_to | proposed_to: agent, proposed: proposed}}}
    end
  end

  def delete_proposed_to(%{id: id}, info) do
    with :ok <- GraphQL.is_authenticated(info),
         {:ok, proposed_to} <- proposed_to(%{id: id}, info),
         {:ok, _} <- Proposals.delete_proposed_to(proposed_to) do
      {:ok, true}
    end
  end

  # def validate_context(pointer) do
  #   if Pointers.table!(pointer).schema in valid_contexts() do
  #     :ok
  #   else
  #     GraphQL.not_permitted("agent")
  #   end
  # end

  # def valid_contexts do
  #   Bonfire.Common.Config.get_ext(:bonfire_valueflows, :valid_agent_schemas, [ValueFlows.Util.user_schema()])
  # end
end
end
