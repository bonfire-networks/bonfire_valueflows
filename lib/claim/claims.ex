# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Claim.Claims do
  import Bonfire.Common.Utils, only: [maybe_put: 3, attr_get_id: 2, maybe: 2, maybe_ok_error: 2]

  import Bonfire.Common.Config, only: [repo: 0]


  alias ValueFlows.Claim
  alias ValueFlows.Claim.Queries

  alias Bonfire.Common.Pointers

  def one(filters), do: repo().single(Queries.query(Claim, filters))

  def many(filters \\ []), do: {:ok, repo().many(Queries.query(Claim, filters))}

  def preload_all(%Claim{} = claim) do
    # shouldn't fail
    {:ok, claim} = one(id: claim.id, preload: :all)
    claim
  end

  def create(%{} = creator, %{id: _} = provider, %{id: _} = receiver, %{} = attrs) do
    repo().transact_with(fn ->
      attrs = prepare_attrs(attrs)

      with {:ok, provider_ptr} <- Pointers.one(id: provider.id),
           {:ok, receiver_ptr} <- Pointers.one(id: receiver.id) do
        Claim.create_changeset(creator, provider_ptr, receiver_ptr, attrs)
        |> Claim.validate_required()
        |> repo().insert()
        |> maybe_ok_error(&preload_all/1)
      end
    end)
  end

  def update(%Claim{} = claim, %{} = attrs) do
    repo().transact_with(fn ->
      attrs = prepare_attrs(attrs)

      claim
      |> Claim.update_changeset(attrs)
      |> repo().update()
      |> maybe_ok_error(&preload_all/1)
    end)
  end

  def soft_delete(%Claim{} = claim) do
    Bonfire.Repo.Delete.soft_delete(claim)
  end

  defp prepare_attrs(attrs) do
    attrs
    |> maybe_put(:action_id, attr_get_id(attrs, :action) |> ValueFlows.Knowledge.Action.Actions.id())
    |> maybe_put(:context_id,
      attrs |> Map.get(:in_scope_of) |> maybe(&List.first/1)
    )
    |> maybe_put(:resource_conforms_to_id, attr_get_id(attrs, :resource_conforms_to))
    |> maybe_put(:triggered_by_id, attr_get_id(attrs, :triggered_by))
  end
end
