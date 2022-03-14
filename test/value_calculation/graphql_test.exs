defmodule ValueFlows.ValueCalculation.GraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  import Bonfire.Common.Simulation, only: [some: 2]
  import Bonfire.Quantify.Simulate, only: [fake_unit!: 1]

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.ValueCalculation.ValueCalculations

  @schema Bonfire.API.GraphQL.Schema

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

    @tag :skip
    test "fetches with full nesting by ID (via Absinthe.run)" do
      user = fake_agent!()
      calc = fake_value_calculation!(user, %{
        in_scope_of: [fake_agent!().id],
        value_unit: fake_unit!(user).id,
        action: action_id(),
        value_action: action_id(),
        resource_conforms_to: fake_resource_specification!(user),
        value_resource_conforms_to: fake_resource_specification!(user),
      })

      assert queried =
        Bonfire.API.GraphQL.QueryHelper.run_query_id(
          calc.id,
          @schema,
          :value_calculation,
          3
        )

      assert_value_calculation(queried)
    end
  end

  describe "valueCalculationsPages" do
    test "returns a paginated list of value calculations" do
      user = fake_agent!()
      calcs = some(5, fn -> fake_value_calculation!(user) end)
      after_calc = List.first(calcs)
      # deleted
      some(2, fn ->
        calc = fake_value_calculation!(user)
        {:ok, calc} = ValueCalculations.soft_delete(calc)
        calc
      end)

      q = value_calculations_pages_query()
      conn = user_conn(user)
      vars = %{after: [after_calc.id], limit: 2}
      assert page = grumble_post_key(q, conn, :value_calculations_pages, vars)
      assert Enum.count(calcs) == page["totalCount"]
      assert List.first(page["edges"])["id"] == after_calc.id
    end
  end

  describe "createValueCalculation" do
    test "creates a new value calculation" do
      user = fake_agent!()
      unit = fake_unit!(user)

      q = create_value_calculation_mutation()
      conn = user_conn(user)
      vars = %{value_calculation: value_calculation(%{value_unit: unit.id})}
      assert %{"valueCalculation" => calc} =
        grumble_post_key(q, conn, :create_value_calculation, vars)
      assert_value_calculation(calc)
    end

    test "fails for a guest user" do
      unit = fake_unit!(fake_agent!())

      q = create_value_calculation_mutation()
      vars = %{value_calculation: value_calculation(%{value_unit: unit.id})}
      assert [%{"code" => "needs_login"}] = grumble_post_errors(q, json_conn(), vars)
    end
  end

  describe "updateValueCalculation" do
    test "updates an existing value calculation" do
      user = fake_agent!()
      calc = fake_value_calculation!(user)

      q = update_value_calculation_mutation()
      conn = user_conn(user)
      vars = %{value_calculation: value_calculation(%{id: calc.id})}
      assert %{"valueCalculation" => updated} =
        grumble_post_key(q, conn, :update_value_calculation, vars)
      assert_value_calculation(calc)
      assert calc.id == updated["id"]
    end

    test "fails for a guest user" do
      calc = fake_value_calculation!(fake_agent!())

      q = update_value_calculation_mutation()
      vars = %{value_calculation: value_calculation(%{id: calc.id})}
      assert [%{"code" => "needs_login"}] = grumble_post_errors(q, json_conn(), vars)
    end
  end

  describe "deleteValueCalculation" do
    test "deletes an existing value calculation" do
      user = fake_agent!()
      calc = fake_value_calculation!(user)

      q = delete_value_calculation_mutation()
      conn = user_conn(user)
      assert true = grumble_post_key(q, conn, :delete_value_calculation, %{id: calc.id})
    end

    test "fails for a guest user" do
      calc = fake_value_calculation!(fake_agent!())

      q = delete_value_calculation_mutation()
      assert [%{"code" => "needs_login"}] = grumble_post_errors(q, json_conn(), %{id: calc.id})
    end
  end
end
