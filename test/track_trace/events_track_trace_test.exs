defmodule ValueFlows.EconomicEvent.EconomicEventsTrackTraceTest do
  use Bonfire.ValueFlows.DataCase, async: true

  import Bonfire.Common.Simulation

  import ValueFlows.Simulate

  import Bonfire.Geolocate.Simulate

  import ValueFlows.Test.Faking

  alias ValueFlows.EconomicEvent.EconomicEvents

  describe "track" do
    test "Return the process to which it is an input" do
      user = fake_agent!()
      process = fake_process!(user)

      event =
        fake_economic_event!(user, %{
          input_of: process.id,
          action: "consume"
        })

      assert {:ok, [tracked_process]} = EconomicEvents.track(event)
      assert process.id == tracked_process.id
    end

    test "return an economic Resource which it affected as the output of a process" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      resource = fake_economic_resource!(user, %{}, unit)
      another_resource = fake_economic_resource!(user, %{}, unit)

      process = fake_process!(user)

      event =
        fake_economic_event!(
          user,
          %{
            output_of: process.id,
            action: "produce"
          },
          unit
        )

      _event_a =
        fake_economic_event!(
          user,
          %{
            output_of: process.id,
            action: "produce",
            resource_inventoried_as: resource.id
          },
          unit
        )

      _event_b =
        fake_economic_event!(
          user,
          %{
            output_of: process.id,
            action: "produce",
            resource_inventoried_as: another_resource.id
          },
          unit
        )

      assert {:ok, resources} = EconomicEvents.track(event)

      ids = Enum.map(resources, & &1.id)
      assert resource.id in ids
      assert another_resource.id in ids
    end

    test "if it is a transfer or move event, the EconomicResource labelled toResourceInventoriedAs" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      resource = fake_economic_resource!(user, %{}, unit)

      event =
        fake_economic_event!(
          user,
          %{
            action: "transfer",
            to_resource_inventoried_as: resource.id,
            provider: user.id,
            receiver: user.id
          },
          unit
        )

      assert {:ok, [tracked_resource]} = EconomicEvents.track(event)
      assert resource.id == tracked_resource.id
    end

    test "if it is a transfer or move event part of a process, the distinct EconomicResource labelled toResourceInventoriedAs" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      resource = fake_economic_resource!(user, %{}, unit)
      process = fake_process!(user)

      event =
        fake_economic_event!(
          user,
          %{
            action: "transfer",
            output_of: process.id,
            resource_inventoried_as: resource.id,
            # to_resource_inventoried_as: resource.id,
            provider: user.id,
            receiver: user.id
          },
          unit
        )

      assert {:ok, resources} = EconomicEvents.track(event)
      ids = Enum.map(resources, & &1.id)
      assert resource.id in ids
    end
  end

  describe "trace" do
    test "Return the process to which it is an output" do
      user = fake_agent!()
      process = fake_process!(user)

      event =
        fake_economic_event!(user, %{
          output_of: process.id,
          action: "produce"
        })

      assert {:ok, [traced_process]} = EconomicEvents.trace(event)

      assert process.id == traced_process.id
    end

    test "return an economic Resource which it affected as the input of a process" do
      user = fake_agent!()
      resource = fake_economic_resource!(user)
      another_resource = fake_economic_resource!(user)
      process = fake_process!(user)

      event =
        fake_economic_event!(user, %{
          input_of: process.id,
          action: "consume"
        })

      _event_a =
        fake_economic_event!(user, %{
          input_of: process.id,
          action: "use",
          resource_inventoried_as: resource.id
        })

      _event_b =
        fake_economic_event!(user, %{
          input_of: process.id,
          action: "cite",
          resource_inventoried_as: another_resource.id
        })

      assert {:ok, resources} = EconomicEvents.trace(event)
      assert Enum.map(resources, & &1.id) == [resource.id, another_resource.id]
    end

    test "if it is a transfer or move event, then the previous
          EconomicResource is the resourceInventoriedAs" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      resource = fake_economic_resource!(user, %{}, unit)

      event =
        fake_economic_event!(
          user,
          %{
            action: "transfer",
            resource_inventoried_as: resource.id,
            provider: user.id,
            receiver: user.id
          },
          unit
        )

      assert {:ok, [traced_resource]} = EconomicEvents.trace(event)
      assert resource.id == traced_resource.id
    end
  end
end
