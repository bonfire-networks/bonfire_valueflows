defmodule ValueFlows.EconomicEvent.EventsTrackTraceGraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true


  import Bonfire.Common.Simulation

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  # alias Grumble.PP
  alias ValueFlows.EconomicEvent.EconomicEvents

  import Bonfire.Geolocate.Simulate
  # import Bonfire.Geolocate.Test.Faking

  @debug false
  @schema Bonfire.API.GraphQL.Schema


  describe "EconomicEvent.track" do
    test "Returns a list of EconomicResources or Processes" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      process = fake_process!(user)
      another_process = fake_process!(user)

      resource = fake_economic_resource!(user, %{}, unit)
      another_resource = fake_economic_resource!(user, %{}, unit)

      event =
        fake_economic_event!(
          user,
          %{
            input_of: process.id,
            output_of: another_process.id,
            resource_inventoried_as: resource.id,
            to_resource_inventoried_as: another_resource.id,
            action: "transfer"
          },
          unit
        )

      q = economic_event_query(fields: [track: [:__typename]])
      conn = user_conn(user)

      assert event = grumble_post_key(q, conn, :economic_event, %{id: event.id})
      assert Enum.count(event["track"]) >= 3
    end
  end

  describe "EconomicEvent.trace" do
    test "Returns a list of economic events that are outputs" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      process = fake_process!(user)
      another_process = fake_process!(user)

      resource = fake_economic_resource!(user, %{}, unit)
      another_resource = fake_economic_resource!(user, %{}, unit)

      event =
        fake_economic_event!(
          user,
          %{
            input_of: process.id,
            output_of: another_process.id,
            resource_inventoried_as: resource.id,
            to_resource_inventoried_as: another_resource.id,
            action: "transfer"
          },
          unit
        )

      q = economic_event_query(fields: [trace: [:__typename]])
      conn = user_conn(user)

      assert event = grumble_post_key(q, conn, :economic_event, %{id: event.id})
      assert Enum.count(event["trace"]) >= 2
    end
  end

end
