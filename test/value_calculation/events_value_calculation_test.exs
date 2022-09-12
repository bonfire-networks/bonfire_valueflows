defmodule ValueFlows.EventsValueCalculationTest do
  use Bonfire.ValueFlows.DataCase, async: true

  import Bonfire.Quantify.Simulate, only: [fake_unit!: 1]
  import ValueFlows.Simulate
  import ValueFlows.Test.Faking
  import ValueFlows.Observe.Simulate

  alias ValueFlows.EconomicEvent.EconomicEvents
  alias ValueFlows.Knowledge.Action.Actions

  alias ValueFlows.Observe.Observations

  alias Decimal, as: D

  describe "create a reciprocal event" do
    test "that has a matching action" do
      user = fake_agent!()
      action = action()

      calc =
        fake_value_calculation!(user, %{
          action: action.id,
          formula: "(+ 1 effortQuantity)"
        })

      event = fake_economic_event!(user, %{action: action.id})

      assert {:ok, reciprocal} = EconomicEvents.one(calculated_using_id: calc.id)

      assert reciprocal = EconomicEvents.preload_all(reciprocal)
      assert reciprocal.action_id == calc.value_action_id

      assert reciprocal.resource_quantity.has_numerical_value ==
               1.0 + reciprocal.effort_quantity.has_numerical_value
    end

    test "effort quantity if action is work or use" do
      user = fake_agent!()
      action = action()

      assert {:ok, value_action} =
               ["use", "work"]
               |> Faker.Util.pick()
               |> Actions.action()

      calc =
        fake_value_calculation!(user, %{
          action: action.id,
          value_action: value_action.id,
          formula: "(+ 1 resourceQuantity)"
        })

      event = fake_economic_event!(user, %{action: action.id})

      assert {:ok, reciprocal} = EconomicEvents.one(calculated_using_id: calc.id)

      assert reciprocal = EconomicEvents.preload_all(reciprocal)

      assert reciprocal.effort_quantity.has_numerical_value ==
               D.to_float(
                 D.add(
                   D.from_float(1.0),
                   D.from_float(reciprocal.resource_quantity.has_numerical_value)
                 )
               )
    end

    test "use of quality" do
      user = fake_agent!()
      unit = fake_unit!(user)
      action = action()

      calc =
        fake_value_calculation!(user, %{
          action: action.id,
          formula: "(* quality resourceQuantity 2)"
        })

      resource = fake_economic_resource!(user, %{}, unit)

      phenon = fake_observable_phenomenon!(user)

      assert {:ok, observation} =
               Observations.create(
                 user,
                 observation(
                   %{},
                   resource,
                   fake_observable_property!(user),
                   phenon
                 )
               )

      event =
        fake_economic_event!(
          user,
          %{
            action: action.id,
            resource_inventoried_as: resource.id
          },
          unit
        )

      assert {:ok, reciprocal} = EconomicEvents.one(calculated_using_id: calc.id)

      assert reciprocal = EconomicEvents.preload_all(reciprocal)

      assert reciprocal.resource_quantity.has_numerical_value ==
               D.to_float(
                 D.mult(
                   D.from_float(phenon.formula_quantifier),
                   D.mult(
                     D.from_float(reciprocal.resource_quantity.has_numerical_value),
                     D.new(2)
                   )
                 )
               )
    end

    # not needed for current project
    @skip
    test "side effects are computed correctly" do
      user = fake_agent!()
      calc = fake_value_calculation!(user, %{formula: "(* 0.5 effortQuantity)"})
      event = fake_economic_event!(user, %{action: action.id})

      assert false = "TODO"
    end
  end
end
