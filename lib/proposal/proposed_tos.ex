# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Proposal.ProposedTos do
  import Bonfire.Common.Utils, only: [maybe_put: 3, attr_get_id: 2, maybe: 2]

  import Bonfire.Common.Config, only: [repo: 0]
  # alias Bonfire.GraphQL
  alias Bonfire.GraphQL.{Fields, Page}

  alias ValueFlows.Proposal
  alias ValueFlows.Proposal

  alias ValueFlows.Proposal.{
    ProposedTo,
    ProposedToQueries,
    ProposedIntentQueries,
    ProposedIntent,
    Queries
  }

  alias ValueFlows.Planning.Intent

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
  def delete(proposed_to), do: Bonfire.Repo.Delete.soft_delete(proposed_to)


  def ap_publish_activity(activity_name, thing) do
    ValueFlows.Util.Federation.ap_publish_activity(activity_name, :proposed_to, thing, 4, [
      :published_in
    ])
  end

  def ap_receive_activity(creator, activity, object) do
    IO.inspect(object, label: "ap_receive_activity - handle ProposedTo")
    # TODO
    # ValueFlows.Util.Federation.ap_receive_activity(creator, activity, object, &create/2)
    nil
  end

end
