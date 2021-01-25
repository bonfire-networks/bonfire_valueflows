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

      assert [event_fetched, reciprocal] = EconomicEvents.many(action_id: action.id)
      # assert reciprocal.calculated_using_id == calc.id
    end
  end
end
