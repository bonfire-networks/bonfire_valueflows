# SPDX-License-Identifier: AGPL-3.0-only
if Code.ensure_loaded?(Bonfire.API.GraphQL) do
  defmodule ValueFlows.Claim.GraphQL do
    import Untangle

    import Bonfire.Common.Config, only: [repo: 0]

    alias Bonfire.Common.Needles
    alias Bonfire.API.GraphQL
    alias Bonfire.API.GraphQL.FetchPage
    alias Bonfire.API.GraphQL.ResolveField
    alias Bonfire.API.GraphQL.ResolveRootPage

    alias ValueFlows.Claim.Claims

    def claim(%{id: id}, info) do
      ResolveField.run(%ResolveField{
        module: __MODULE__,
        fetcher: :fetch_claim,
        context: id,
        info: info
      })
    end

    def claims(page_opts, info) do
      ResolveRootPage.run(%ResolveRootPage{
        module: __MODULE__,
        fetcher: :fetch_claims,
        page_opts: page_opts,
        info: info,
        cursor_validators: [
          &(is_integer(&1) and &1 >= 0),
          &Needle.UID.cast/1
        ]
      })
    end

    def fetch_claim(_info, id) do
      Claims.one([:default, id: id])
    end

    def fetch_events(page_opts, info) do
      FetchPage.run(%FetchPage{
        queries: ValueFlows.Claim.Queries,
        query: ValueFlows.Claim,
        page_opts: page_opts,
        base_filters: [
          :default,
          creator: GraphQL.current_user(info)
        ]
      })
    end

    def fetch_triggered_by_edge(%{triggered_by_id: id} = thing, _, _)
        when is_binary(id) do
      thing = repo().preload(thing, :triggered_by)
      {:ok, Map.get(thing, :triggered_by)}
    end

    def fetch_triggered_by_edge(_, _, _) do
      {:ok, nil}
    end

    def create_claim(
          %{claim: %{provider: provider_id, receiver: receiver_id} = attrs},
          info
        ) do
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, provider} <-
             Needles.one(id: provider_id, skip_boundary_check: true),
           {:ok, receiver} <-
             Needles.one(id: receiver_id, skip_boundary_check: true),
           {:ok, claim} <- Claims.create(user, provider, receiver, attrs) do
        {:ok, %{claim: claim}}
      end
    end

    def update_claim(%{claim: %{id: id} = attrs}, info) do
      with :ok <- GraphQL.is_authenticated(info),
           {:ok, claim} <- claim(%{id: id}, info),
           {:ok, claim} <- Claims.update(claim, attrs) do
        {:ok, %{claim: claim}}
      end
    end

    def delete_claim(%{id: id}, info) do
      with :ok <- GraphQL.is_authenticated(info),
           {:ok, claim} <- claim(%{id: id}, info),
           {:ok, _} <- Claims.soft_delete(claim) do
        {:ok, true}
      end
    end
  end
end
