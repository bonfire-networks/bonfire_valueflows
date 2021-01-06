defmodule ValueFlows.ValueCalculation.GraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  import Bonfire.Quantify.Simulate, only: [fake_unit!: 1]

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  @schema Bonfire.GraphQL.Schema

  describe "valueCalculation" do
    test "fetches by ID (via HTTP)" do
      user = fake_agent!()
      calc = fake_value_calculation!(user)

      q = value_calculation_query()
      conn = user_conn(user)
      assert fetched = grumble_post_key(q, conn, :value_calculation, %{id: calc.id})
      assert_value_calculation(fetched)
      assert fetched["id"] == calc.id
    end

    test "fetches with full nesting by ID (via Absinthe.run)" do
      user = fake_agent!()
      calc = fake_value_calculation!(user, %{
        in_scope_of: [fake_agent!().id],
        value_unit: fake_unit!(user).id,
      })

      assert queried =
        Bonfire.GraphQL.QueryHelper.run_query_id(
          calc.id,
          @schema,
          :value_calculation,
          3
        )

      assert_value_calculation(queried)
    end
  end

  describe "valueCalculations" do
    test "returns a paginated list of value calculations" do
    end
  end

  describe "createValueCalculation" do
    test "creates a new value calculation" do
      user = fake_agent!()

      q = create_value_calculation_mutation()
      conn = user_conn(user)
      vars = %{value_calculation: value_calculation()}
      assert %{"valueCalculation" => calc} =
        grumble_post_key(q, conn, :create_value_calculation, vars)
    end

    test "fails for a guest user" do
      q = create_value_calculation_mutation()
      vars = %{value_calculation: value_calculation()}
      assert [%{"code" => "needs_login"}] = grumble_post_errors(q, json_conn(), vars)
    end
  end

  describe "updateValueCalculation" do
    test "updates an existing value calculation" do
    end

    test "fails for a guest user" do
    end
  end

  describe "deleteValueCalculation" do
    test "deletes an existing value calculation" do
    end

    test "fails for a guest user" do
    end
  end
end
