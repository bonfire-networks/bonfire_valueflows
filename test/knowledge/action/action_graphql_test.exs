defmodule Valueflows.Knowledge.Action.GraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true

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
      # user = fake_agent!()
      action = action()

      assert queried =
               Bonfire.API.GraphQL.QueryHelper.run_query_id(
                 action.label,
                 @schema,
                 :action,
                 3,
                 nil,
                 @debug
               )

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
