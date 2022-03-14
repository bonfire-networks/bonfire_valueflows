defmodule ValueFlows.Proposal.GraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true


  import Bonfire.Common.Simulation


  import Bonfire.Geolocate.Simulate

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  @debug false
  @schema Bonfire.API.GraphQL.Schema

  describe "proposal" do
    test "fetches a proposal by ID (via GraphQL HTTP)" do
      user = fake_agent!()
      proposal = fake_proposal!(user)

      q = proposal_query()
      #IO.inspect(q)

      conn = user_conn(user)

      assert proposal_queried =
               grumble_post_key(q, conn, :proposal, %{id: proposal.id}, "test", false)

      assert_proposal_full(proposal_queried)
    end

    @tag :skip
    test "fetches a full nested proposal by ID (via Absinthe.run)" do
      user = fake_agent!()
      parent = fake_agent!()
      location = fake_geolocation!(user)

      proposal =
        fake_proposal!(user, %{
          in_scope_of: [parent.id],
          eligible_location_id: location.id
        })

      intent = fake_intent!(user)

      some(5, fn ->
        fake_proposed_intent!(proposal, intent)
      end)

      some(5, fn ->
        fake_proposed_to!(fake_agent!(), proposal)
      end)

      assert proposal_queried =
               Bonfire.API.GraphQL.QueryHelper.run_query_id(
                 proposal.id,
                 @schema,
                 :proposal,
                 4,
                 nil,
                 @debug
               )

      assert_proposal_full(proposal_queried)
    end
  end

  describe "proposal.publishes" do
    test "fetches all proposed intents for a proposal" do
      user = fake_agent!()
      proposal = fake_proposal!(user)
      intent = fake_intent!(user)

      some(5, fn ->
        fake_proposed_intent!(proposal, intent)
      end)

      q = proposal_query(fields: [publishes: [:id]])
      conn = user_conn(user)
      assert proposal = grumble_post_key(q, conn, :proposal, %{id: proposal.id})
      assert Enum.count(proposal["publishes"]) == 5
    end
  end

  describe "proposal.publishes.publishedIn" do
    test "lists the proposals for a proposed intent" do
      user = fake_agent!()
      proposal = fake_proposal!(user)
      intent = fake_intent!(user)

      some(5, fn -> fake_proposed_intent!(proposal, intent) end)

      q =
        proposal_query(
          fields: [
            publishes: [:id, published_in: proposal_fields()]
          ]
        )

      conn = user_conn(user)
      assert fetched = grumble_post_key(q, conn, :proposal, %{id: proposal.id})
      assert_proposal(proposal, fetched)
    end
  end

  describe "proposal.publishedTo" do
    test "fetches all proposed to items for a proposal" do
      user = fake_agent!()
      proposal = fake_proposal!(user)

      some(5, fn ->
        fake_proposed_to!(fake_agent!(), proposal)
      end)

      q = proposal_query(fields: [published_to: [:id]])
      conn = user_conn(user)
      assert proposal = grumble_post_key(q, conn, :proposal, %{id: proposal.id})
      assert Enum.count(proposal["publishedTo"]) == 5
    end
  end

  describe "proposal.eligibleLocation" do
    test "fetches an associated eligible location" do
      user = fake_agent!()
      location = fake_geolocation!(user)
      proposal = fake_proposal!(user, %{eligible_location_id: location.id})

      q = proposal_query(fields: [eligible_location: [:id]])
      conn = user_conn(user)
      assert proposal = grumble_post_key(q, conn, :proposal, %{id: proposal.id})
      assert proposal["eligibleLocation"]["id"] == location.id
    end
  end

  describe "proposal.inScopeOf" do
    test "returns the scope of the proposal" do
      user = fake_agent!()
      parent = fake_agent!()
      proposal = fake_proposal!(user, %{in_scope_of: [parent.id]})

      q = proposal_query(fields: [in_scope_of: [:__typename]])
      conn = user_conn(user)
      assert proposal = grumble_post_key(q, conn, :proposal, %{id: proposal.id})
      assert hd(proposal["inScopeOf"])["__typename"] == "Person"
    end
  end

  describe "proposalPages" do
    test "fetches a page of proposals" do
      user = fake_agent!()
      proposals = some(5, fn -> fake_proposal!(user) end)
      after_proposal = List.first(proposals)

      q = proposals_pages_query()
      conn = user_conn(user)
      vars = %{after: after_proposal.id, limit: 2}
      assert %{"edges" => fetched} = grumble_post_key(q, conn, :proposalsPages, vars)
      assert Enum.count(fetched) == 2
      assert List.first(fetched)["id"] == after_proposal.id
    end

    test "fetches several pages of proposals" do
      user = fake_agent!()
      _proposals = some(6, fn -> fake_proposal!(user) end)

      q = proposals_pages_query()
      conn = user_conn(user)
      vars = %{limit: 2}
      assert response = grumble_post_key(q, conn, :proposalsPages, vars)

      assert %{
               "edges" => fetched,
               "totalCount" => 6,
               "pageInfo" => %{"endCursor" => end_cursor, "hasNextPage" => true}
             } = response

      assert Enum.count(fetched) == 2

      after_cursor = List.first(end_cursor)
      vars = %{after: after_cursor, limit: 4}
      assert %{"edges" => page2} = grumble_post_key(q, conn, :proposalsPages, vars)
      assert Enum.count(page2) == 4
      # assert List.first(fetched)["id"] == after_cursor
   end
  end

  describe "createProposal" do
    test "creates a new proposal" do
      user = fake_agent!()
      q = create_proposal_mutation()
      conn = user_conn(user)
      vars = %{proposal: proposal_input()}
      assert proposal = grumble_post_key(q, conn, :create_proposal, vars)["proposal"]
      assert_proposal_full(proposal)
    end

    test "creates a new proposal with a scope" do
      user = fake_agent!()
      parent = fake_agent!()

      q = create_proposal_mutation(fields: [in_scope_of: [:__typename]])
      conn = user_conn(user)
      vars = %{proposal: proposal_input(%{"inScopeOf" => [parent.id]})}
      assert proposal = grumble_post_key(q, conn, :create_proposal, vars)["proposal"]
      assert_proposal_full(proposal)
      assert hd(proposal["inScopeOf"])["__typename"] == "Person"
    end

    test "creates a new proposal with an eligible location" do
      user = fake_agent!()
      location = fake_geolocation!(user)

      q = create_proposal_mutation(fields: [eligible_location: [:id]])
      conn = user_conn(user)
      vars = %{proposal: proposal_input(%{"eligibleLocation" => location.id})}
      assert proposal = grumble_post_key(q, conn, :create_proposal, vars)["proposal"]
      assert proposal["eligibleLocation"]["id"] == location.id
    end
  end

  describe "updateProposal" do
    test "updates an existing proposal" do
      user = fake_agent!()
      proposal = fake_proposal!(user)

      q = update_proposal_mutation()
      conn = user_conn(user)
      vars = %{proposal: update_proposal_input(%{"id" => proposal.id})}
      assert proposal = grumble_post_key(q, conn, :update_proposal, vars)["proposal"]
      assert_proposal_full(proposal)
    end

    test "updates an existing proposal with a new scope" do
      user = fake_agent!()
      scope = fake_agent!()
      proposal = fake_proposal!(user, %{in_scope_of: [scope.id]})

      new_scope = fake_agent!()
      q = update_proposal_mutation()
      conn = user_conn(user)

      vars = %{
        proposal: update_proposal_input(%{"id" => proposal.id, "inScopeOf" => [new_scope.id]})
      }

      assert proposal = grumble_post_key(q, conn, :update_proposal, vars)["proposal"]
      assert_proposal_full(proposal)
    end
  end

  describe "deleteProposal" do
    test "deletes an existing proposal" do
      user = fake_agent!()
      proposal = fake_proposal!(user)

      q = delete_proposal_mutation()
      conn = user_conn(user)
      assert grumble_post_key(q, conn, :delete_proposal, %{"id" => proposal.id})
    end
  end
end
