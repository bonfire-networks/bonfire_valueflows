defmodule ValueFlows.ResourceSpecification.FederateTest do
  use Bonfire.ValueFlows.DataCase
  import Bonfire.Common.Simulation
  import Bonfire.Geolocate.Simulate
  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  @debug false
  @schema Bonfire.API.GraphQL.Schema

  describe "resource spec" do
    test "federates/publishes" do
      user = fake_agent!()

      resource_spec = fake_resource_specification!(user)

      #IO.inspect(pre_fed: proposal)

      assert {:ok, activity} = Bonfire.Federate.ActivityPub.Publisher.publish("create", resource_spec)
      dump(activity)

      assert activity.object.pointer_id == resource_spec.id
      assert activity.local == true

      assert activity.object.data["name"] =~ resource_spec.name
    end
  end
end
