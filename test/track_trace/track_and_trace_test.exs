defmodule ValueFlows.TrackAndTraceTest do
  use Bonfire.ValueFlows.DataCase, async: true

  import Bonfire.Common.Simulation




  import ValueFlows.Simulate

  # import Bonfire.Geolocate.Simulate

  # import ValueFlows.Test.Faking

  alias ValueFlows.Observation.EconomicEvent.EconomicEvents
  alias ValueFlows.Observation.EconomicResource.EconomicResources

  describe "Track" do

   test "starting from a resource we track the chain until the second level" do
      user = fake_agent!()
      resource = fake_economic_resource!(user)
      process = fake_process!(user)
      _input_events = some(3, fn -> fake_economic_event!(user, %{
        input_of: process.id,
        resource_inventoried_as: resource.id,
        action: "use"
      }) end)
      assert {:ok, input_events} = EconomicResources.track(resource)
      for event <- input_events do
        assert {:ok, [track_process]} = EconomicEvents.track(event)
        assert track_process.id == process.id
      end
    end
    test "starting from a resource we track the chain until the third level" do
      user = fake_agent!()
      resource = fake_economic_resource!(user)
      process = fake_process!(user)
      _input_events = some(3, fn -> fake_economic_event!(user, %{
        input_of: process.id,
        resource_inventoried_as: resource.id,
        action: "use"
      }) end)
      assert {:ok, input_events} = EconomicResources.track(resource)
      for event <- input_events do
        assert {:ok, [track_process]} = EconomicEvents.track(event)
        assert track_process.id == process.id
      end
    end

  end

  describe "Trace" do
    test "return an economic event that is not part of a process from tracing a resource" do
      user = fake_agent!()
      resource = fake_economic_resource!(user)
      _event = fake_economic_event!(user, %{
        resource_inventoried_as: resource.id,
        action: "produce"
      })
      assert {:ok, events} = EconomicResources.trace(resource)
      # IO.inspect(events)
      for event <- events do

        assert {:ok, []} = EconomicEvents.trace(event)
      end
    end
  end
end
