defmodule Valueflows.Knowledge.Action.GraphQLTest do
  use Bonfire.ValueFlows.DataCase, async: true

  # import Bonfire.Common.Simulation

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  @debug false
  @schema Bonfire.API.GraphQL.Schema

  describe "action" do
    test "fetches an existing action by label (via HTTP)" do
      user = fake_agent!()
      action = action()

      q = action_query()
      conn = user_conn(user)
      assert_action(grumble_post_key(q, conn, :action, %{id: action.label}))
    end

    test "fetches an existing action by label (via Absinthe.run)" do
      user = fake_agent!()
      action = action()

      # root queries need a login, and run_query_id passes no context
      q = Bonfire.API.GraphQL.QueryHelper.query_with_id(@schema, :action, 3)

      assert {:ok, %{data: %{"action" => queried}}} =
               Absinthe.run(q, @schema,
                 variables: %{"id" => action.label},
                 context: %{current_user: user}
               )

      assert queried

      assert_action(queried)
    end
  end

  describe "actions" do
    test "fetches all actions" do
      user = fake_agent!()
      _actions = actions()
      q = actions_query()
      conn = user_conn(user)

      assert actions = grumble_post_key(q, conn, :actions, %{})
      assert Enum.count(actions) > 1
    end
  end
end
