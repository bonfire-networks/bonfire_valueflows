defmodule ValueFlows.Proposal.FederateTest do
  use Bonfire.ValueFlows.DataCase

  import Bonfire.Common.Simulation


  import Bonfire.Geolocate.Simulate



  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  @debug false
  @schema Bonfire.GraphQL.Schema

  describe "proposal" do
    test "federates/publishes a proposal" do
      user = fake_agent!()

      location = fake_geolocation!(user)

      proposal = fake_proposal!(user, %{eligible_location_id: location.id})

      intent = fake_intent!(user)

      fake_proposed_intent!(proposal, intent)

      fake_proposed_to!(fake_agent!(), proposal)

      #IO.inspect(pre_fed: proposal)

      assert {:ok, activity} = Bonfire.Federate.ActivityPub.Publisher.publish("create", proposal)
      #IO.inspect(published: activity) ########

      assert activity.pointer_id == proposal.id
      assert activity.local == true

      assert activity.data["object"]["name"] == proposal.name
    end
  end
end
