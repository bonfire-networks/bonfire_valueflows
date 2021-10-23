defmodule ValueFlows.EconomicEvent.FederateTest do
  use Bonfire.ValueFlows.DataCase

  import Bonfire.Common.Simulation
  import Bonfire.Geolocate.Simulate
  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  @debug false
  @schema Bonfire.GraphQL.Schema

  describe "economic event" do
    test "federates/publishes" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      event =
        fake_economic_event!(
          user,
          %{
            input_of: fake_process!(user).id,
            output_of: fake_process!(user).id,
            resource_conforms_to: fake_resource_specification!(user).id,
            to_resource_inventoried_as: fake_economic_resource!(user, %{}, unit).id,
            resource_inventoried_as: fake_economic_resource!(user, %{}, unit).id
          },
          unit
        )

      #IO.inspect(pre_fed: event)

      assert {:ok, activity} = Bonfire.Federate.ActivityPub.Publisher.publish("create", event)
      #IO.inspect(published: activity)

      assert activity.pointer_id == event.id
      assert activity.local == true

      assert activity.data["object"]["summary"] == event.note
    end
  end
end
