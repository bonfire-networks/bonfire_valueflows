defmodule ValueFlows.Proposal.ProposedToGraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  # import Bonfire.Common.Simulation

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  describe "propose_to" do
    test "creates a new proposed to item" do
      user = fake_agent!()
      proposal = fake_proposal!(user)
      agent = fake_agent!()

      q = propose_to_mutation(fields: [proposed: [:id], proposed_to: [:id]])

      conn = user_conn(user)

      vars = %{
        "proposed" => proposal.id,
        "proposedTo" => agent.id
      }

      assert proposed_to = grumble_post_key(q, conn, :propose_to, vars)["proposedTo"]

      assert_proposed_to(proposed_to)
      assert proposed_to["proposed"]["id"] == proposal.id
      assert proposed_to["proposedTo"]["id"] == agent.id
    end
  end

  describe "delete_proposed_to" do
    test "deletes an existing proposed to item" do
      user = fake_agent!()
      proposed_to = fake_proposed_to!(fake_agent!(), fake_proposal!(user))

      q = delete_proposed_to_mutation()
      conn = user_conn(user)

      assert grumble_post_key(q, conn, :delete_proposed_to, %{
               id: proposed_to.id
             })
    end
  end
end
