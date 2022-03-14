# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Claim.GraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  # import Bonfire.Common.Simulation


  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  @schema Bonfire.API.GraphQL.Schema

  describe "Claim" do
    test "fetches a claim by ID (via HTTP)" do
      user = fake_agent!()
      claim = fake_claim!(user)

      q = claim_query()
      conn = user_conn(user)
      assert fetched = grumble_post_key(q, conn, :claim, %{id: claim.id})
      assert_claim(fetched)
      assert fetched["id"] == claim.id
    end

    @tag :skip
    test "fetched a full nested claim by ID (via Absinthe.run)" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)
      claim = fake_claim!(user, %{
        in_scope_of: [fake_agent!().id],
        resource_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        effort_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        resource_conforms_to: fake_resource_specification!(user).id,
        triggered_by: fake_economic_event!(user).id,
      })

      assert queried =
        Bonfire.API.GraphQL.QueryHelper.run_query_id(
          claim.id,
          @schema,
          :claim,
          3
        )

      assert_claim(queried)
    end
  end

  describe "createClaim" do
    test "creates a new claim" do
      user = fake_agent!()

      q = create_claim_mutation()
      conn = user_conn(user)

      vars = %{claim: claim_input(%{
        "provider" => fake_agent!().id,
        "receiver" => fake_agent!().id,
      })}

      assert claim = grumble_post_key(q, conn, :create_claim, vars)["claim"]
      assert_claim(claim)
    end

    test "fails for a guest user" do
      q = create_claim_mutation()
      vars = %{claim: claim_input(%{
        "provider" => fake_agent!().id,
        "receiver" => fake_agent!().id,
      })}
      assert [%{"code" => "needs_login"}] = grumble_post_errors(q, json_conn(), vars)
    end
  end

  describe "updateClaim" do
    test "updates an existing claim" do
      user = fake_agent!()
      claim = fake_claim!(user)

      q = update_claim_mutation()
      conn = user_conn(user)

      vars = %{claim: claim_input(%{"id" => claim.id})}

      assert updated = grumble_post_key(q, conn, :update_claim, vars)["claim"]
      assert_claim(updated)
      assert updated["id"] == claim.id
    end

    test "fails for a guest user" do
      claim = fake_claim!(fake_agent!())
      q = update_claim_mutation()
      vars = %{claim: claim_input(%{"id" => claim.id})}
      assert [%{"code" => "needs_login"}] = grumble_post_errors(q, json_conn(), vars)
    end
  end

  describe "deleteClaim" do
    test "deletes an existing claim" do
      user = fake_agent!()
      claim = fake_claim!(user)

      q = delete_claim_mutation()
      conn = user_conn(user)

      vars = %{id: claim.id}

      assert grumble_post_key(q, conn, :delete_claim, vars)
    end

    test "fails for a guest user" do
      claim = fake_claim!(fake_agent!())
      q = delete_claim_mutation()
      vars = %{id: claim.id}
      assert [%{"code" => "needs_login"}] = grumble_post_errors(q, json_conn(), vars)
    end
  end
end
