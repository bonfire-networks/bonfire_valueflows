defmodule ValueFlows.EconomicResource.EconomicResourcesTrackTraceTest do
  use Bonfire.ValueFlows.DataCase, async: true

  import Bonfire.Common.Simulation

  import ValueFlows.Simulate

  import Bonfire.Geolocate.Simulate

  import ValueFlows.Test.Faking

  alias ValueFlows.EconomicResource.EconomicResources

  describe "EconomicResources.track" do
    test "Returns a list of EconomicEvents affecting the resource that are inputs to Processes " do
      user = fake_agent!()
      resource = fake_economic_resource!(user)
      process = fake_process!(user)

      input_events =
        some(3, fn ->
          fake_economic_event!(user, %{
            input_of: process.id,
            resource_inventoried_as: resource.id,
            action: "use"
          })
        end)

      _output_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            resource_inventoried_as: resource.id,
            action: "produce"
          })
        end)

      assert {:ok, events} = EconomicResources.track(resource)

      ids = Enum.map(events, & &1.id)

      for %{id: id} <- input_events do
        assert id in ids
      end
    end

    test "Returns a list of transfer/move EconomicEvents with the resource defined as the resourceInventoriedAs" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      resource = fake_economic_resource!(user, %{}, unit)

      input_events =
        some(3, fn ->
          fake_economic_event!(
            user,
            %{
              resource_inventoried_as: resource.id,
              action: "transfer"
            },
            unit
          )
        end)

      assert {:ok, events} = EconomicResources.track(resource)

      ids = Enum.map(events, & &1.id)

      for %{id: id} <- input_events do
        assert id in ids
      end
    end
  end

  describe "EconomicResources.trace" do
    test "Returns a list of EconomicEvents affecting the resource that are outputs from Processes" do
      user = fake_agent!()
      resource = fake_economic_resource!(user)
      process = fake_process!(user)

      _input_events =
        some(3, fn ->
          fake_economic_event!(user, %{
            input_of: process.id,
            to_resource_inventoried_as: resource.id,
            action: "use"
          })
        end)

      output_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            to_resource_inventoried_as: resource.id,
            action: "produce"
          })
        end)

      assert {:ok, trace_events} = EconomicResources.trace(resource)

      ids = Enum.map(trace_events, & &1.id)

      for %{id: id} <- output_events do
        assert id in ids
      end
    end

    test "Returns a list of transfer/move EconomicEvents with the resource defined as the toResourceInventoriedAs" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)
      resource = fake_economic_resource!(user, %{}, unit)

      input_events =
        some(3, fn ->
          fake_economic_event!(
            user,
            %{
              provider: user.id,
              receiver: user.id,
              to_resource_inventoried_as: resource.id,
              action: "transfer"
            },
            unit
          )
        end)

      assert {:ok, events} = EconomicResources.trace(resource)

      ids = Enum.map(events, & &1.id)

      for %{id: id} <- input_events do
        assert id in ids
      end
    end
  end
end
