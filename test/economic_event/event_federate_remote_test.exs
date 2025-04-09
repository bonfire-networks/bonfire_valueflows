defmodule ValueFlows.EconomicEvent.FederateRemoteTest do
  use Bonfire.ValueFlows.ConnCase
  @moduletag :federation

  alias Bonfire.Common.Utils
  import Bonfire.Common.Simulation
  import Bonfire.Geolocate.Simulate
  import ValueFlows.Simulate
  import ValueFlows.Test.Faking
  alias Bonfire.Federate.ActivityPub.Simulate
  alias ValueFlows.EconomicEvent.EconomicEvents
  alias Bonfire.Common.TestInstanceRepo

  @debug false
  @schema Bonfire.API.GraphQL.Schema

  setup do
    {remote_user, remote_actor} =
      TestInstanceRepo.apply(fn ->
        # repo().delete_all(ActivityPub.Object)
        remote_user = fake_agent!()
        {remote_user, Bonfire.Me.Characters.character_url(remote_user)}
      end)

    [
      # uses a test instance that should also be running
      remote_actor: remote_actor
    ]
  end

  describe "outgoing economic event" do
    @tag :skip
    # @tag :test_instance
    test "transfer an existing economic resource to a remote agent/actor by AP URI", context do
      ActivityPub.Utils.cache_clear()

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
            "resourceQuantity" =>
              Bonfire.Quantify.Simulate.measure_input(unit, %{
                "hasNumericalValue" => 42
              }),
            "resourceInventoriedAs" => resource_inventoried_as.id,
            "toResourceInventoriedAs" => to_resource_inventoried_as.id,
            # "provider" => user.id,
            "receiver" => context[:remote_actor]
          })
      }

      assert response =
               grumble_post_key(
                 q,
                 conn,
                 :create_economic_event,
                 vars,
                 "test",
                 @debug
               )

      assert event = response["economicEvent"]
      assert_economic_event(event)

      assert {:ok, local_event} = EconomicEvents.one(id: event["id"])

      assert Bonfire.Common.URIs.canonical_url(event["receiver"]) ==
               context[:remote_actor]

      assert {:ok, ap} = Bonfire.Federate.ActivityPub.Outgoing.push_now!(local_event)

      # info(ap)

      assert ap.object.pointer_id == local_event.id
      assert ap.local == true

      assert ap.object.data["summary"] =~ local_event.note

      # assert ap.data["id"] == Bonfire.Common.URIs.canonical_url(event) # FIXME?

      {:ok, remote_actor} = ActivityPub.Actor.get_cached_or_fetch(ap_id: context[:remote_actor])

      assert ap.object.data["receiver"]["id"] == context[:remote_actor]

      assert event["resourceInventoriedAs"]["accountingQuantity"][
               "hasNumericalValue"
             ] ==
               resource_inventoried_as.accounting_quantity.has_numerical_value -
                 42

      assert event["toResourceInventoriedAs"]["accountingQuantity"][
               "hasNumericalValue"
             ] ==
               to_resource_inventoried_as.accounting_quantity.has_numerical_value +
                 42

      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :federator_outgoing)

      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :federator_outgoing)
    end

    #   test "transfer an existing economic resource to a remote agent/actor by username" do
    #     ActivityPub.Utils.cache_clear()

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

    # assert {:ok, activity} = Bonfire.Federate.ActivityPub.Outgoing.push_now!(local_event)

    #     assert ap.object.pointer_id == local_event.id
    #     assert ap.local == true

    #     assert ap.object.data["summary"] =~ local_event.note

    #     {:ok, remote_actor} = ActivityPub.Actor.get_cached_or_fetch(ap_id: @remote_actor)
    #     assert ap.object.data["receiver"]["id"] == @remote_actor

    #     assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :federator_outgoing)
    #     assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :federator_outgoing)
    #   end
  end
end
