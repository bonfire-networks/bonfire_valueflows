defmodule ValueFlows.TrackAndTraceTest do
  use Bonfire.ValueFlows.DataCase, async: true

  import Bonfire.Common.Simulation

  import ValueFlows.Simulate

  # import Bonfire.Geolocate.Simulate

  # import ValueFlows.Test.Faking

  alias ValueFlows.EconomicEvent.EconomicEvents
  alias ValueFlows.EconomicResource.EconomicResources

  describe "Track" do
    test "starting from a resource we track the nested chain until the second level" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)
      resource = fake_economic_resource!(user, %{}, unit)
      process = fake_process!(user)

      _input_events =
        some(3, fn ->
          fake_economic_event!(
            user,
            %{
              input_of: process.id,
              resource_inventoried_as: resource.id,
              action: "use"
            },
            unit
          )
        end)

      assert {:ok, input_events} = EconomicResources.track(resource)

      for event <- input_events do
        assert {:ok, chain} = ValueFlows.EconomicEvent.Track.track(event)
        if length(chain) > 0, do: assert(process.id in Enum.map(chain, & &1.id))
      end
    end
  end

  describe "Trace" do
    test "starting from a resource we trace the nested chain until the third level" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)
      resource = fake_economic_resource!(user, %{}, unit)
      process = fake_process!(user)

      output_events =
        some(3, fn ->
          fake_economic_event!(
            user,
            %{
              output_of: process.id,
              resource_inventoried_as: resource.id,
              action: "transfer"
            },
            unit
          )
        end)

      last_resource = List.last(output_events) |> Map.get(:to_resource_inventoried_as)

      assert {:ok, output_events} = EconomicResources.trace(last_resource)

      for event <- output_events do
        assert {:ok, chain} = ValueFlows.EconomicEvent.Trace.trace(event)
        if length(chain) > 0, do: assert(process.id in Enum.map(chain, & &1.id))
      end
    end

    test "return an economic event that is not part of a process from tracing a resource" do
      user = fake_agent!()
      resource = fake_economic_resource!(user)

      _event =
        fake_economic_event!(user, %{
          resource_inventoried_as: resource.id,
          action: "produce"
        })

      assert {:ok, events} = EconomicResources.trace(resource)
      # IO.inspect(events)
      for event <- events do
        assert {:ok, []} = ValueFlows.EconomicEvent.Trace.trace(event)
      end
    end
  end
end
