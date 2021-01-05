defmodule ValueFlows.ValueCalculation.ValueCalculationsTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  # import Bonfire.Common.Simulation



  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.ValueCalculation.ValueCalculations

  describe "create" do
    test "with only required parameters" do
      user = fake_agent!()

      assert {:ok, calc} = ValueCalculations.create(user, value_calculation())
      assert_value_calculation(calc)
      assert calc.creator.id == user.id
    end

    test "with a complex formula" do
      user = fake_agent!()

      attrs = %{formula: "(* 2 (+ effortQuantity 1.5) (pow availableQuantity 2))"}
      assert {:ok, calc} = ValueCalculations.create(user, value_calculation(attrs))
      assert_value_calculation(calc)
    end

    test "with an invalid formula" do
      user = fake_agent!()

      attrs = %{formula: "(* 2 missing)"}
      assert {:error, %{original_failure: "Undefined variable: \"missing\""}} =
        ValueCalculations.create(user, value_calculation(attrs))
    end

    test "with a context" do
      user = fake_agent!()
      context = fake_agent!()

      attrs = %{in_scope_of: [context.id]}
      assert {:ok, calc} = ValueCalculations.create(user, value_calculation(attrs))
      assert_value_calculation(calc)
      assert calc.context.id == context.id
    end

    test "with a value unit" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      attrs = %{value_unit: unit.id}
      assert {:ok, calc} = ValueCalculations.create(user, value_calculation(attrs))
      assert_value_calculation(calc)
      assert calc.value_unit.id == unit.id
    end
  end
end
