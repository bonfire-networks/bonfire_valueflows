# SPDX-License-Identifier: AGPL-3.0-only
if Code.ensure_loaded?(Bonfire.API.GraphQL) do
defmodule ValueFlows.Proposal.ProposedIntentGraphQL do
  use Absinthe.Schema.Notation

  alias Bonfire.API.GraphQL

  alias Bonfire.API.GraphQL
  alias Bonfire.API.GraphQL.{
    ResolveField
  }

  alias ValueFlows.Proposal.Proposals
  # alias ValueFlows.Proposal.ProposedIntent

  def proposed_intent(%{id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_proposed_intent,
      context: id,
      info: info
    })
  end

  # FIXME ADD BATCHING, THIS IS NESTED DATA!!!!1!!!one!!!

  def intent_in_proposal_edge(%{id: proposed_intent_id}, _, info) do
    with {:ok, proposed_intent} <-
           ValueFlows.Proposal.ProposedIntents.one([:default, id: proposed_intent_id]) do
      ValueFlows.Planning.Intent.GraphQL.intent(%{id: proposed_intent.publishes_id}, info)
    end
  end

  def proposal_in_intent_edge(%{id: proposed_intent_id}, _, info) do
    with {:ok, proposed_intent} <-
           ValueFlows.Proposal.ProposedIntents.one([:default, id: proposed_intent_id]) do
      ValueFlows.Proposal.GraphQL.proposal(%{id: proposed_intent.published_in_id}, info)
    end
  end

  def publishes_edge(%{id: proposal_id}, _, _info) do
    ValueFlows.Proposal.ProposedIntents.many([:default, published_in_id: proposal_id])
  end

  def publishes_edge(_, _, _info) do
    {:ok, nil}
  end

  def published_in_edge(%{id: intent_id}, _, _info) do
    ValueFlows.Proposal.ProposedIntents.many([:default, publishes_id: intent_id])
  end

  def fetch_proposed_intent(_info, id) do
    ValueFlows.Proposal.ProposedIntents.one([:default, id: id])
  end

  def propose_intent(
        %{published_in: published_in_proposal_id, publishes: publishes_intent_id} = params,
        info
      ) do
    with :ok <- GraphQL.is_authenticated(info),
         {:ok, published_in} <-
           ValueFlows.Proposal.GraphQL.proposal(%{id: published_in_proposal_id}, info),
         {:ok, publishes} <-
           ValueFlows.Planning.Intent.GraphQL.intent(%{id: publishes_intent_id}, info),
         {:ok, proposed_intent} <- ValueFlows.Proposal.ProposedIntents.propose_intent(published_in, publishes, params) do
      {:ok,
       %{proposed_intent: %{proposed_intent | published_in: published_in, publishes: publishes}}}
    end
  end

  def delete_proposed_intent(%{id: id}, info) do
    with :ok <- GraphQL.is_authenticated(info),
         {:ok, proposed_intent} <- proposed_intent(%{id: id}, info),
         {:ok, _} <- ValueFlows.Proposal.ProposedIntents.delete(proposed_intent) do
      {:ok, true}
    end
  end
end
end
