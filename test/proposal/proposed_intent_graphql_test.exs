defmodule ValueFlows.Proposal.ProposedIntentGraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  # import Bonfire.Common.Simulation

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  describe "propose_intent" do
    test "creates a new proposed intent" do
      user = fake_agent!()
      proposal = fake_proposal!(user)
      intent = fake_intent!(user)

      q = propose_intent_mutation(fields: [publishes: [:id], published_in: [:id]])

      conn = user_conn(user)

      vars =
        proposed_intent_input(%{
          "publishes" => intent.id,
          "publishedIn" => proposal.id
        })

      assert proposed_intent =
               grumble_post_key(q, conn, :propose_intent, vars)[
                 "proposedIntent"
               ]

      assert_proposed_intent(proposed_intent)
      assert proposed_intent["publishedIn"]["id"] == proposal.id
      assert proposed_intent["publishes"]["id"] == intent.id
    end
  end

  describe "delete_proposed_intent" do
    test "deletes a proposed intent" do
      user = fake_agent!()

      proposed_intent =
        fake_proposed_intent!(
          fake_proposal!(user),
          fake_intent!(user)
        )

      q = delete_proposed_intent_mutation()

      conn = user_conn(user)
      vars = %{id: proposed_intent.id}
      assert grumble_post_key(q, conn, :delete_proposed_intent, vars)
    end
  end
end
