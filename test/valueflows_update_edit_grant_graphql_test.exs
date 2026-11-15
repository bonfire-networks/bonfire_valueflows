defmodule ValueFlows.UpdateEditGrantGraphQLTest do
  @moduledoc """
  The GraphQL update mutations of intents, economic events and proposals check the `:edit` verb: someone granted `:edit` on the object may update it without being its creator, someone with no grant may not, and the creator always may.
  """
  use Bonfire.ValueFlows.DataCase, async: true

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.Planning.Intent.Intents
  alias ValueFlows.EconomicEvent.EconomicEvents
  alias ValueFlows.Proposal.Proposals

  defp grant_edit!(grantee, object) do
    grants =
      Bonfire.Boundaries.Controlleds.grant_role(grantee.id, object, :edit,
        skip_boundary_check: true
      )

    assert [_ | _] = grants
    assert Enum.all?(grants, &match?({:ok, _}, &1))
  end

  describe "updateIntent" do
    setup do
      owner = fake_agent!()
      {:ok, owner: owner, other: fake_agent!(), intent: fake_intent!(owner)}
    end

    defp intent_vars(intent, note), do: %{intent: %{"id" => intent.id, "note" => note}}

    test "someone granted :edit may update it", %{other: other, intent: intent} do
      grant_edit!(other, intent)

      assert grumble_post_key(
               update_intent_mutation(),
               user_conn(other),
               :update_intent,
               intent_vars(intent, "edited by grantee")
             )

      assert {:ok, %{note: "edited by grantee"}} = Intents.one(id: intent.id)
    end

    test "someone with no grant is refused", %{other: other, intent: intent} do
      assert [_ | _] =
               grumble_post_errors(
                 update_intent_mutation(),
                 user_conn(other),
                 intent_vars(intent, "nope")
               )

      assert {:ok, %{note: note}} = Intents.one(id: intent.id)
      assert note != "nope"
    end

    test "the creator may (control)", %{owner: owner, intent: intent} do
      assert grumble_post_key(
               update_intent_mutation(),
               user_conn(owner),
               :update_intent,
               intent_vars(intent, "by owner")
             )

      assert {:ok, %{note: "by owner"}} = Intents.one(id: intent.id)
    end
  end

  describe "updateEconomicEvent" do
    setup do
      owner = fake_agent!()
      {:ok, owner: owner, other: fake_agent!(), event: fake_economic_event!(owner)}
    end

    defp event_vars(event, note), do: %{event: %{"id" => event.id, "note" => note}}

    test "someone granted :edit may update it", %{other: other, event: event} do
      grant_edit!(other, event)

      assert grumble_post_key(
               update_economic_event_mutation(),
               user_conn(other),
               :update_economic_event,
               event_vars(event, "edited by grantee")
             )

      assert {:ok, %{note: "edited by grantee"}} = EconomicEvents.one(id: event.id)
    end

    test "someone with no grant is refused", %{other: other, event: event} do
      assert [_ | _] =
               grumble_post_errors(
                 update_economic_event_mutation(),
                 user_conn(other),
                 event_vars(event, "nope")
               )

      assert {:ok, %{note: note}} = EconomicEvents.one(id: event.id)
      assert note != "nope"
    end

    test "the creator may (control)", %{owner: owner, event: event} do
      assert grumble_post_key(
               update_economic_event_mutation(),
               user_conn(owner),
               :update_economic_event,
               event_vars(event, "by owner")
             )

      assert {:ok, %{note: "by owner"}} = EconomicEvents.one(id: event.id)
    end
  end

  describe "updateProposal" do
    setup do
      owner = fake_agent!()
      {:ok, owner: owner, other: fake_agent!(), proposal: fake_proposal!(owner)}
    end

    defp proposal_vars(proposal, note), do: %{proposal: %{"id" => proposal.id, "note" => note}}

    test "someone granted :edit may update it", %{other: other, proposal: proposal} do
      grant_edit!(other, proposal)

      assert grumble_post_key(
               update_proposal_mutation(),
               user_conn(other),
               :update_proposal,
               proposal_vars(proposal, "edited by grantee")
             )

      assert {:ok, %{note: "edited by grantee"}} = Proposals.one(id: proposal.id)
    end

    test "someone with no grant is refused", %{other: other, proposal: proposal} do
      assert [_ | _] =
               grumble_post_errors(
                 update_proposal_mutation(),
                 user_conn(other),
                 proposal_vars(proposal, "nope")
               )

      assert {:ok, %{note: note}} = Proposals.one(id: proposal.id)
      assert note != "nope"
    end

    test "the creator may (control)", %{owner: owner, proposal: proposal} do
      assert grumble_post_key(
               update_proposal_mutation(),
               user_conn(owner),
               :update_proposal,
               proposal_vars(proposal, "by owner")
             )

      assert {:ok, %{note: "by owner"}} = Proposals.one(id: proposal.id)
    end
  end
end
