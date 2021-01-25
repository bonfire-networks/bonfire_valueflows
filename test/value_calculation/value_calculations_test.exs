defmodule ValueFlows.ValueCalculation.ValueCalculationsTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  import Bonfire.Common.Simulation, only: [some: 2]
  import Bonfire.Quantify.Simulate, only: [fake_unit!: 1]

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.ValueCalculation.ValueCalculations

  describe "one" do
    test "by ID" do
      calc = fake_value_calculation!(fake_agent!())

      assert {:ok, fetched} = ValueCalculations.one(id: calc.id)
      assert_value_calculation(fetched)
      assert calc.id == fetched.id
    end

    test "by user" do
      user = fake_agent!()
      calc = fake_value_calculation!(user)

      assert {:ok, fetched} = ValueCalculations.one(creator: user)
      assert_value_calculation(fetched)
      assert calc.creator_id == user.id
    end

    test "by context" do
      user = fake_agent!()
      context = fake_agent!()
      calc = fake_value_calculation!(user, %{in_scope_of: [context.id]})

      assert {:ok, fetched} = ValueCalculations.one(context_id: context.id)
      assert_value_calculation(fetched)
      assert calc.context_id == context.id
    end

    test "default filter handles deleted items" do
      calc = fake_value_calculation!(fake_agent!())
      assert {:ok, calc} = ValueCalculations.soft_delete(calc)
      assert {:error, :not_found} = ValueCalculations.one([:default, id: calc.id])
    end
  end

  describe "many" do
    test "fetches multiple items with a filter" do
      user = fake_agent!()
      calcs = some(5, fn -> fake_value_calculation!(user) end)

      assert {:ok, fetched} = ValueCalculations.many()
      assert Enum.count(fetched) == 5
      assert {:ok, fetched} = ValueCalculations.many([creator: user])
      assert Enum.count(fetched) == 5
      assert {:ok, fetched} = ValueCalculations.many([id: hd(calcs).id])
      assert Enum.count(fetched) == 1
    end
  end

  describe "create" do
    test "with only required parameters" do
      user = fake_agent!()

      attrs = value_calculation(%{value_unit: fake_unit!(user)})
      assert {:ok, calc} = ValueCalculations.create(user, attrs)
      assert_value_calculation(calc)
      assert calc.creator.id == user.id
    end

    test "with a complex formula" do
      user = fake_agent!()

      attrs = %{
        formula: "(* 2 (+ effortQuantity 1.5) (max availableQuantity 2))",
        value_unit: fake_unit!(user),
      }

      assert {:ok, calc} = ValueCalculations.create(user, value_calculation(attrs))
      assert_value_calculation(calc)
    end

    test "with an invalid formula" do
      user = fake_agent!()

      attrs = %{formula: "(* 2 missing)", value_unit: fake_unit!(user)}
      assert {:error, %{original_failure: "Undefined variable: \"missing\""}} =
        ValueCalculations.create(user, value_calculation(attrs))
    end

    test "with a context" do
      user = fake_agent!()
      context = fake_agent!()

      attrs = %{in_scope_of: [context.id], value_unit: fake_unit!(user)}
      assert {:ok, calc} = ValueCalculations.create(user, value_calculation(attrs))
      assert_value_calculation(calc)
      assert calc.context.id == context.id
    end

    test "with a conforming resource" do
      user = fake_agent!()
      resource = fake_resource_specification!(user)

      attrs = %{resource_conforms_to: resource, value_unit: fake_unit!(user)}
      assert {:ok, calc} = ValueCalculations.create(user, value_calculation(attrs))
      assert_value_calculation(calc)
      assert calc.resource_conforms_to.id == resource.id
    end

    test "with a value conforming resource" do
      user = fake_agent!()
      resource = fake_resource_specification!(user)

      attrs = %{value_resource_conforms_to: resource, value_unit: fake_unit!(user)}
      assert {:ok, calc} = ValueCalculations.create(user, value_calculation(attrs))
      assert_value_calculation(calc)
      assert calc.value_resource_conforms_to.id == resource.id
    end
  end

  describe "update" do
    test "an existing value calculation" do
      calc = fake_value_calculation!(fake_agent!())

      attrs = value_calculation(%{formula: "(+ 1 2 3 4)"})
      assert {:ok, updated} = ValueCalculations.update(calc, attrs)
      assert_value_calculation(updated)
      assert updated.id == calc.id
      assert updated != calc
    end

    test "with a context" do
      calc = fake_value_calculation!(fake_agent!())

      context = fake_agent!()
      attrs = %{in_scope_of: [context.id]}

      assert {:ok, updated} = ValueCalculations.update(calc, attrs)
      assert_value_calculation(updated)
      assert updated.context_id == context.id
    end

    test "with a value unit" do
      calc = fake_value_calculation!(fake_agent!())

      unit = fake_unit!(fake_agent!())
      attrs = %{value_unit: unit.id}

      assert {:ok, updated} = ValueCalculations.update(calc, attrs)
      assert_value_calculation(updated)
      assert updated.value_unit_id == unit.id
    end
  end

  describe "soft_delete" do
    test "updates deleted at" do
      calc = fake_value_calculation!(fake_agent!())

      assert {:ok, calc} = ValueCalculations.soft_delete(calc)
      assert calc.deleted_at
    end
  end
end
