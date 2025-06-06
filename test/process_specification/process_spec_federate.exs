defmodule ValueFlows.ProcessSpecification.FederateTest do
  use Bonfire.ValueFlows.DataCase
  @moduletag :federation

  import Bonfire.Common.Simulation
  import Bonfire.Geolocate.Simulate
  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  @debug false
  @schema Bonfire.API.GraphQL.Schema

  describe "process spec" do
    test "federates/publishes" do
      user = fake_agent!()

      process_spec = fake_process_specification!(user)

      # IO.inspect(pre_fed: proposal)

      assert {:ok, activity} = Bonfire.Federate.ActivityPub.Outgoing.push_now!(process_spec)

      # IO.inspect(published: activity) ########

      assert activity.object.pointer_id == process_spec.id
      assert activity.local == true

      assert activity.object.data["name"] =~ process_spec.name
    end
  end
end
