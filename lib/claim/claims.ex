# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Claim.Claims do
  use Bonfire.Common.Utils,
    only: [maybe: 2]

  import Bonfire.Common.Config, only: [repo: 0]

  alias ValueFlows.Claim
  alias ValueFlows.Claim.Queries

  alias Bonfire.Common.Needles

  @behaviour Bonfire.Federate.ActivityPub.FederationModules
  def federation_module, do: ["ValueFlows:Claim", "Claim"]

  def one(filters), do: repo().single(Queries.query(Claim, filters))

  def many(filters \\ []), do: {:ok, repo().many(Queries.query(Claim, filters))}

  def preload_all(%Claim{} = claim) do
    # shouldn't fail
    {:ok, claim} = one(id: claim.id, preload: :all)
    claim
  end

  def create(
        %{} = creator,
        %{id: _} = provider,
        %{id: _} = receiver,
        %{} = attrs
      ) do
    repo().transact_with(fn ->
      attrs = prepare_attrs(attrs)

      with {:ok, provider_ptr} <-
             Needles.one(id: provider.id, skip_boundary_check: true),
           {:ok, receiver_ptr} <-
             Needles.one(id: receiver.id, skip_boundary_check: true) do
        Claim.create_changeset(creator, provider_ptr, receiver_ptr, attrs)
        |> Claim.validate_required()
        |> repo().insert()
        |> Errors.maybe_ok_error(&preload_all/1)
      end
    end)
  end

  def create(%{} = creator, %{} = attrs) do
    repo().transact_with(fn ->
      attrs = prepare_attrs(attrs)

      with {:ok, claim} <-
             Claim.create_changeset(creator, attrs)
             |> Claim.validate_required()
             |> repo().insert() do
        preload_all(claim)
      end
    end)
  end

  def update(%Claim{} = claim, %{} = attrs) do
    repo().transact_with(fn ->
      attrs = prepare_attrs(attrs)

      claim
      |> Claim.update_changeset(attrs)
      |> repo().update()
      |> Errors.maybe_ok_error(&preload_all/1)
    end)
  end

  def soft_delete(%Claim{} = claim) do
    Bonfire.Common.Repo.Delete.soft_delete(claim)
  end

  defp prepare_attrs(attrs) do
    attrs
    |> Enums.maybe_put(
      :action_id,
      Enums.attr_get_id(attrs, :action) |> ValueFlows.Knowledge.Action.Actions.id()
    )
    |> Enums.maybe_put(
      :context_id,
      attrs |> Map.get(:in_scope_of) |> maybe(&List.first/1)
    )
    |> Enums.maybe_put(
      :resource_conforms_to_id,
      Enums.attr_get_id(attrs, :resource_conforms_to)
    )
    |> Enums.maybe_put(:triggered_by_id, Enums.attr_get_id(attrs, :triggered_by))
  end

  def ap_publish_activity(subject, activity_name, thing) do
    ValueFlows.Util.Federation.ap_publish_activity(
      subject,
      activity_name,
      :claim,
      thing,
      3,
      []
    )
  end

  def ap_receive_activity(creator, activity, object) do
    ValueFlows.Util.Federation.ap_receive_activity(
      creator,
      activity,
      object,
      &create/2
    )
  end
end
