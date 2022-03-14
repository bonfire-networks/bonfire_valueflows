defmodule ValueFlows.EconomicResource.TrackTraceGraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  import Bonfire.Common.Simulation

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking
  # alias Grumble.PP
  alias ValueFlows.EconomicResource.EconomicResources

  import Bonfire.Geolocate.Simulate
  # import Bonfire.Geolocate.Test.Faking

  @debug false
  @schema Bonfire.API.GraphQL.Schema

  describe "EconomicResources.track" do
    test "Returns a list of EconomicEvents that are inputs to Processes " do
      user = fake_agent!()
      resource = fake_economic_resource!(user)
      process = fake_process!(user)

      _input_events =
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

      q = economic_resource_query(fields: [track: [:__typename]])
      conn = user_conn(user)

      assert resource = grumble_post_key(q, conn, :economic_resource, %{id: resource.id})
      assert Enum.count(resource["track"]) >= 3
    end

    test "Returns a list of transfer/move EconomicEvents with the resource defined as the resourceInventoriedAs" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      resource = fake_economic_resource!(user, %{}, unit)

      _input_events =
        some(3, fn ->
          fake_economic_event!(user, %{
            resource_inventoried_as: resource.id,
            action: "transfer"
          }, unit)
        end)

      _other_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            resource_inventoried_as: resource.id,
            action: "use"
          }, unit)
        end)

      q = economic_resource_query(fields: [track: [:__typename]])
      conn = user_conn(user)

      assert resource = grumble_post_key(q, conn, :economic_resource, %{id: resource.id})
      assert Enum.count(resource["track"]) >= 3
    end
  end

  # FIXME
  describe "EconomicResources.trace" do
    test "Returns a list of EconomicEvents affecting it that are outputs to Processes " do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      resource = fake_economic_resource!(user, %{}, unit)
      process = fake_process!(user)

      _input_events =
        some(3, fn ->
          fake_economic_event!(user, %{
            input_of: process.id,
            resource_inventoried_as: resource.id,
            action: "use"
          }, unit)
        end)

      _output_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            resource_inventoried_as: resource.id,
            action: "produce"
          }, unit)
        end)

      q = economic_resource_query(fields: [trace: [:__typename]])
      conn = user_conn(user)

      assert resource = grumble_post_key(q, conn, :economic_resource, %{id: resource.id})
      assert Enum.count(resource["trace"]) >= 5
    end

    # FIXME
    test "Returns a list of transfer/move EconomicEvents with the resource defined as the toResourceInventoriedAs" do
      alice = fake_agent!()
      bob = fake_agent!()

      unit = maybe_fake_unit(alice)

      resource = fake_economic_resource!(bob, %{}, unit)

      _input_events =
        some(3, fn ->
          fake_economic_event!(alice, %{
            provider: alice.id,
            receiver: bob.id,
            to_resource_inventoried_as: resource.id,
            action: "transfer"
          }, unit)
        end)

      _other_events =
        some(5, fn ->
          fake_economic_event!(alice, %{
            provider: alice.id,
            receiver: bob.id,
            to_resource_inventoried_as: resource.id,
            action: "use"
          }, unit)
        end)

      q = economic_resource_query(fields: [trace: [:__typename]])

      conn = user_conn(alice)

      assert resource = grumble_post_key(q, conn, :economic_resource, %{id: resource.id})
      assert Enum.count(resource["trace"]) >= 3
    end
  end
end
