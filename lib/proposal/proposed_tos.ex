# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Proposal.ProposedTos do
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
  def federation_module, do: ["ValueFlows:ProposedTo", "ProposedTo"]

  @spec one(filters :: [any]) :: {:ok, ProposedTo.t()} | {:error, term}
  def one(filters),
    do: repo().single(ProposedToQueries.query(ProposedTo, filters))

  @spec many(filters :: [any]) :: {:ok, [ProposedTo]} | {:error, term}
  def many(filters \\ []),
    do: {:ok, repo().many(ProposedToQueries.query(ProposedTo, filters))}

  # if you like it then you should put a ring on it
  @spec propose_to(any, Proposal.t()) :: {:ok, ProposedTo.t()} | {:error, term}
  def propose_to(proposed_to, %Proposal{} = proposed) do
    repo().insert(ProposedTo.changeset(proposed_to, proposed))
  end

  @spec delete(ProposedTo.t()) :: {:ok, ProposedTo.t()} | {:error, term}
  def delete(proposed_to),
    do: Bonfire.Common.Repo.Delete.soft_delete(proposed_to)

  def ap_publish_activity(subject, activity_name, thing) do
    ValueFlows.Util.Federation.ap_publish_activity(
      subject,
      activity_name,
      :proposed_to,
      thing,
      4,
      [
        :published_in
      ]
    )
  end

  def ap_receive_activity(creator, activity, object) do
    IO.inspect(object, label: "ap_receive_activity - handle ProposedTo")
    # TODO
    # ValueFlows.Util.Federation.ap_receive_activity(creator, activity, object, &create/2)
    nil
  end
end
