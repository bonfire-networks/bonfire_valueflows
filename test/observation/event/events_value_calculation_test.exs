defmodule ValueFlows.EventsValueCalculationTest do
  use Bonfire.ValueFlows.DataCase, async: true

  import Bonfire.Quantify.Simulate, only: [fake_unit!: 1]
  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.EconomicEvent.EconomicEvents

  describe "create a reciprocal event" do
    test "that has a matching action" do
      user = fake_agent!()
      action = action()
      calc = fake_value_calculation!(user, %{action: action.id, formula: "(+ 1 2)"})
      event = fake_economic_event!(user, %{action: action.id})

      assert {:ok, [event_fetched, reciprocal]} = EconomicEvents.many(action_id: action.id)
      # assert reciprocal.calculated_using_id == calc.id
      assert reciprical = EconomicEvents.preload_all(reciprocal)
      # FIXME
      # assert reciprocal.resource_quantity.has_numerical_value == 3.0

      assert {:ok, measure} = Bonfire.Quantify.Measures.one(id: reciprocal.resource_quantity_id)
      assert measure.has_numerical_value == 3.0
    end
  end
end
