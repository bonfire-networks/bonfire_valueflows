# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Proposal.ProposedIntents do
  use Bonfire.Common.Utils, only: [maybe: 2]

  import Bonfire.Common.Config, only: [repo: 0]
  # alias Bonfire.API.GraphQL
  alias Bonfire.API.GraphQL.Fields
  alias Bonfire.API.GraphQL.Page

  alias ValueFlows.Proposal
  alias ValueFlows.Proposal

  alias ValueFlows.Proposal.ProposedTo
  alias ValueFlows.Proposal.ProposedToQueries
  alias ValueFlows.Proposal.ProposedIntentQueries
  alias ValueFlows.Proposal.ProposedIntent
  alias ValueFlows.Proposal.Queries

  alias ValueFlows.Planning.Intent

  @behaviour Bonfire.Federate.ActivityPub.FederationModules
  def federation_module, do: ["ValueFlows:ProposedIntent", "ProposedIntent"]

  @spec one(filters :: [any]) :: {:ok, ProposedIntent.t()} | {:error, term}
  def one(filters),
    do: repo().single(ProposedIntentQueries.query(ProposedIntent, filters))

  @spec many(filters :: [any]) :: {:ok, [ProposedIntent.t()]} | {:error, term}
  def many(filters \\ []),
    do: {:ok, repo().many(ProposedIntentQueries.query(ProposedIntent, filters))}

  @spec propose_intent(Proposal.t(), Intent.t(), map) ::
          {:ok, ProposedIntent.t()} | {:error, term}
  def propose_intent(%Proposal{} = proposal, %Intent{} = intent, attrs) do
    with {:ok, proposed_intent} <-
           repo().insert(ProposedIntent.changeset(proposal, intent, attrs)) do
      {:ok,
       proposed_intent
       |> Map.put(:publishes, intent)
       |> Map.put(:published_in, proposal)}
    end
  end

  def create(_creator, %{published_in: proposal, publishes: intent} = attrs) do
    propose_intent(proposal, intent, attrs)
  end

  @spec delete(ProposedIntent.t()) :: {:ok, ProposedIntent.t()} | {:error, term}
  def delete(%ProposedIntent{} = proposed_intent) do
    Bonfire.Common.Repo.Delete.soft_delete(proposed_intent)
  end

  def ap_publish_activity(subject, activity_name, thing) do
    ValueFlows.Util.Federation.ap_publish_activity(
      subject,
      activity_name,
      :proposal,
      thing,
      4,
      [
        :published_in
      ]
    )
  end

  def ap_receive_activity(creator, activity, object) do
    IO.inspect(object, label: "ap_receive_activity - handle ProposedIntent")

    ValueFlows.Util.Federation.ap_receive_activity(
      creator,
      activity,
      object,
      &create/2
    )
  end
end
