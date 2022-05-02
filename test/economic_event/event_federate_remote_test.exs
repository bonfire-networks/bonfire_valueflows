defmodule ValueFlows.EconomicEvent.FederateRemoteTest do
  use Bonfire.ValueFlows.ConnCase

  alias Bonfire.Common.Utils
  import Bonfire.Common.Simulation
  import Bonfire.Geolocate.Simulate
  import ValueFlows.Simulate
  import ValueFlows.Test.Faking
  alias Bonfire.Federate.ActivityPub.Simulate
  alias ValueFlows.EconomicEvent.EconomicEvents

  @debug false
  @schema Bonfire.API.GraphQL.Schema

  # uses a test instance that should also be running
  @test_username "test"
  @instance "localhost:4000"
  @remote_instance "http://"<>@instance
  @actor_name @test_username<>"@"<>@instance
  @remote_actor @remote_instance<>"/pub/actors/"<>@test_username
  @remote_actor_url @remote_instance<>"/@"<>@test_username
  @webfinger @remote_instance<>"/.well-known/webfinger?resource=acct:"<>@actor_name

  # setup do
  # # tell Tesla not to mock?
  # Application.put_env(:tesla, :adapter, Tesla.Adapter.Hackney)
  # end

  describe "outgoing economic event" do

    @tag :test_instance
    test "transfer an existing economic resource to a remote agent/actor by AP URI" do
      Cachex.clear(:ap_actor_cache)
      Cachex.clear(:ap_object_cache)

      user = fake_agent!()

      unit = maybe_fake_unit(user)
      resource_inventoried_as = fake_economic_resource!(user, %{}, unit)
      to_resource_inventoried_as = fake_economic_resource!(user, %{}, unit)

      q =
        create_economic_event_mutation(
          fields: [
            :id,
            receiver: [:id],
            resource_quantity: [:has_numerical_value],
            resource_inventoried_as: [
              :id,
              onhand_quantity: [:has_numerical_value],
              accounting_quantity: [:has_numerical_value]
            ],
            to_resource_inventoried_as: [
              :id,
              onhand_quantity: [:has_numerical_value],
              accounting_quantity: [:has_numerical_value]
            ]
          ]
        )

      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "action" => "transfer",
            "resourceQuantity" => Bonfire.Quantify.Simulate.measure_input(unit, %{"hasNumericalValue" => 42}),
            "resourceInventoriedAs" => resource_inventoried_as.id,
            "toResourceInventoriedAs" => to_resource_inventoried_as.id,
            # "provider" => user.id,
            "receiver" => @remote_actor
          })
      }

      assert response = grumble_post_key(q, conn, :create_economic_event, vars, "test", @debug)
      assert event = response["economicEvent"]
      assert_economic_event(event)

      assert {:ok, local_event} = EconomicEvents.one(id: event["id"])

      assert Bonfire.Common.URIs.canonical_url(event["receiver"]) == @remote_actor

      assert {:ok, ap} = Bonfire.Federate.ActivityPub.Publisher.publish("create", local_event)
      # info(ap)

      assert ap.object.pointer_id == local_event.id
      assert ap.local == true

      assert ap.object.data["summary"] =~ local_event.note

      # assert ap.data["id"] == Bonfire.Common.URIs.canonical_url(event) # FIXME?

      {:ok, remote_actor} = ActivityPub.Actor.get_or_fetch_by_ap_id(@remote_actor)
      assert ap.object.data["receiver"]["id"] == @remote_actor

      assert event["resourceInventoriedAs"]["accountingQuantity"]["hasNumericalValue"] ==
               resource_inventoried_as.accounting_quantity.has_numerical_value - 42

      assert event["toResourceInventoriedAs"]["accountingQuantity"]["hasNumericalValue"] ==
               to_resource_inventoried_as.accounting_quantity.has_numerical_value + 42

      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :federator_outgoing)
      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :federator_outgoing)
    end

  #   test "transfer an existing economic resource to a remote agent/actor by username" do
  #     Cachex.clear(:ap_actor_cache)
  #     Cachex.clear(:ap_object_cache)

  #     user = fake_agent!()

  #     unit = maybe_fake_unit(user)
  #     resource_inventoried_as = fake_economic_resource!(user, %{}, unit)
  #     to_resource_inventoried_as = fake_economic_resource!(user, %{}, unit)

  #     q =
  #       create_economic_event_mutation(
  #         fields: [
  #           :id,
  #           receiver: [:id],
  #           resource_quantity: [:has_numerical_value],
  #           resource_inventoried_as: [
  #             :id,
  #             onhand_quantity: [:has_numerical_value],
  #             accounting_quantity: [:has_numerical_value]
  #           ],
  #           to_resource_inventoried_as: [
  #             :id,
  #             onhand_quantity: [:has_numerical_value],
  #             accounting_quantity: [:has_numerical_value]
  #           ]
  #         ]
  #       )

  #     conn = user_conn(user)

  #     vars = %{
  #       event:
  #         economic_event_input(%{
  #           "action" => "transfer",
  #           "resourceQuantity" => Bonfire.Quantify.Simulate.measure_input(unit, %{"hasNumericalValue" => 42}),
  #           "resourceInventoriedAs" => resource_inventoried_as.id,
  #           "toResourceInventoriedAs" => to_resource_inventoried_as.id,
  #           # "provider" => user.id,
  #           "receiver" => @actor_name
  #         })
  #     }

  #     assert response = grumble_post_key(q, conn, :create_economic_event, vars, "test", @debug)
  #     assert event = response["economicEvent"]
  #     assert_economic_event(event)

  #     assert {:ok, local_event} = EconomicEvents.one(id: event["id"])

  #     assert Bonfire.Common.URIs.canonical_url(event["receiver"]) == @remote_actor

  #     assert {:ok, ap} = Bonfire.Federate.ActivityPub.Publisher.publish("create", local_event)

  #     assert ap.object.pointer_id == local_event.id
  #     assert ap.local == true

  #     assert ap.object.data["summary"] =~ local_event.note

  #     {:ok, remote_actor} = ActivityPub.Actor.get_or_fetch_by_ap_id(@remote_actor)
  #     assert ap.object.data["receiver"]["id"] == @remote_actor

  #     assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :federator_outgoing)
  #     assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :federator_outgoing)
  #   end

  end

end
