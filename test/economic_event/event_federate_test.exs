defmodule ValueFlows.EconomicEvent.FederateTest do
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

  import Tesla.Mock

  # mocks used for fetch
  @remote_instance "https://kawen.space"
  @actor_name "karen@kawen.space"
  @remote_actor @remote_instance<>"/users/karen"
  @remote_actor_url @remote_instance<>"/@karen"
  @webfinger @remote_instance<>"/.well-known/webfinger?resource=acct:"<>@actor_name

  # TODO: move this into fixtures
  setup do
    mock(fn
      %{method: :get, url: @remote_actor} ->
        json(Simulate.actor_json(@remote_actor))
      %{method: :get, url: @remote_actor_url} ->
        json(Simulate.actor_json(@remote_actor))
      %{method: :get, url: @webfinger} ->
        json(Simulate.webfingered())
      %{method: :get, url: "http://kawen.space/.well-known/webfinger?resource=acct:karen@kawen.space"} ->
        json(Simulate.webfingered())
      other ->
        warn(other, "mock not configured")
        nil
    end)

    :ok
  end

  describe "outgoing economic event" do
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

      dump(event, "event ready to federate")

      assert {:ok, ap} = Bonfire.Federate.ActivityPub.Publisher.publish("create", event)
      #IO.inspect(published: activity)

      assert ap.object.pointer_id == event.id
      assert ap.local == true

      assert ap.object.data["summary"] =~ event.note
    end

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
      #IO.inspect(published: activity)

      assert ap.object.pointer_id == local_event.id
      assert ap.local == true

      assert ap.object.data["summary"] =~ local_event.note

      # assert activity.data["id"] == Bonfire.Common.URIs.canonical_url(event) # FIXME?

      {:ok, remote_actor} = ActivityPub.Actor.get_or_fetch_by_ap_id(@remote_actor)
      assert ap.object.data["receiver"]["id"] == @remote_actor

      assert event["resourceInventoriedAs"]["accountingQuantity"]["hasNumericalValue"] ==
               resource_inventoried_as.accounting_quantity.has_numerical_value - 42

      assert event["toResourceInventoriedAs"]["accountingQuantity"]["hasNumericalValue"] ==
               to_resource_inventoried_as.accounting_quantity.has_numerical_value + 42
    end

    test "transfer an existing economic resource to a mock remote agent/actor by username" do
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
            "receiver" => @actor_name
          })
      }

      assert response = grumble_post_key(q, conn, :create_economic_event, vars, "test", @debug)
      assert event = response["economicEvent"]
      assert_economic_event(event)

      assert {:ok, local_event} = EconomicEvents.one(id: event["id"])

      assert Bonfire.Common.URIs.canonical_url(event["receiver"]) == @remote_actor

      assert {:ok, ap} = Bonfire.Federate.ActivityPub.Publisher.publish("create", local_event)

      assert ap.object.pointer_id == local_event.id
      assert ap.local == true

      assert ap.object.data["summary"] =~ local_event.note

      {:ok, remote_actor} = ActivityPub.Actor.get_or_fetch_by_ap_id(@remote_actor)
      assert ap.object.data["receiver"]["id"] == @remote_actor

    end
  end

  describe "incoming economic event" do

    test "creates an economic event from an incoming federated activity " do
      Cachex.clear(:ap_actor_cache)
      Cachex.clear(:ap_object_cache)

      {:ok, actor} = ActivityPub.Actor.get_or_fetch_by_ap_id(@remote_actor)

      to = [
        "https://testing.kawen.dance/users/karen",
        "https://www.w3.org/ns/activitystreams#Public"
      ]

      object = %{
        "action" => "https://w3id.org/valueflows#consume",
        "actor" => @remote_actor,
        "attributedTo" => @remote_actor,
        "context" => nil,
        "effortQuantity" => %{
          "hasNumericalValue" => 0.8097386376788132,
          "hasUnit" => "https://kawen.space/pub/objects/01FKSN9FKCH25K3T75TK0BMEP2",
          "id" => "https://kawen.space/pub/objects/01FKSN9FXFXXJ74M53D1ERD3HK",
          "type" => "om2:Measure"
        },
        "hasBeginning" => "2021-09-07T03:05:58.621470Z",
        "hasEnd" => "2022-05-07T12:57:38.913080Z",
        "hasPointInTime" => "2022-04-24T00:53:19.982157Z",
        "id" => "https://kawen.space/pub/objects/01FKSN9FXJM5M7AXR8K7S8769B",
        "inputOf" => %{
          "finished" => false,
          "id" => "https://kawen.space/pub/objects/01FKSN9FKE91BVZ0FZ36PKF2AE",
          "name" => "Schaefer, Wolf and Nolan",
          "summary" => "Autem iste aut dolores explicabo dolores aut.",
          "type" => "ValueFlows:Process"
        },
        "outputOf" => %{
          "finished" => false,
          "id" => "https://kawen.space/pub/objects/01FKSN9FP9MASJXTNA545RKG7B",
          "name" => "Davis-Walsh",
          "summary" => "Rem nesciunt rerum necessitatibus placeat.",
          "type" => "ValueFlows:Process"
        },
        "provider" => %{
          "agentType" => "Person",
          "id" => @remote_actor,
          "name" => "Dr. Annalise Hane",
          "preferredUsername" => "karen",
          "summary" => "Quasi vitae repudiandae et est enim minus aut vero repudiandae.",
          "type" => "Person"
        },
        "published" => "2021-11-06T03:39:50.790006Z",
        "receiver" => %{
          "agentType" => "Person",
          "id" => @remote_actor,
          "name" => "Dr. Annalise Hane",
          "preferredUsername" => "karen",
          "summary" => "Quasi vitae repudiandae et est enim minus aut vero repudiandae.",
          "type" => "Person"
        },
        "resourceConformsTo" => %{
          "id" => "https://kawen.space/pub/objects/01FKSN9FQZA6REGKGJZ6W5HRDQ",
          "name" => "Mueller LLC",
          "summary" => "Quas sit sint consequatur quasi ex quia et ab.",
          "type" => "ValueFlows:ResourceSpecification"
        },
        "resourceInventoriedAs" => %{
          "id" => "https://kawen.space/pub/objects/01FKSN9FVMB34EHMHMED3KJV3Q",
          "name" => "Kulas-Prosacco",
          "primaryAccountable" => @remote_actor,
          "summary" => "Ea esse ad blanditiis numquam dolorem fugit.",
          "trackingIdentifier" => "0d28b152-0fd3-426b-936b-943ad75120aa",
          "type" => "ValueFlows:EconomicResource"
        },
        "resourceQuantity" => %{
          "hasNumericalValue" => 0.6858598450509016,
          "hasUnit" => "https://kawen.space/pub/objects/01FKSN9FKCH25K3T75TK0BMEP2",
          "id" => "https://kawen.space/pub/objects/01FKSN9FXHN49KZXGAMD7A7W4H",
          "type" => "om2:Measure"
        },
        "summary" => "Aut autem nesciunt culpa nostrum enim commodi qui omnis.",
        "toResourceInventoriedAs" => %{
          "id" => "https://kawen.space/pub/objects/01FKSN9FT8AQN4ZEYRA2DVVH4J",
          "name" => "Russel-Fahey",
          "primaryAccountable" => @remote_actor,
          "summary" => "Eos accusamus quae vitae totam rerum neque aut.",
          "trackingIdentifier" => "418ce00f-593b-43fd-a290-2ee18dd23324",
          "type" => "ValueFlows:EconomicResource"
        },
        "type" => "ValueFlows:EconomicEvent"
      }

      params = %{
        actor: actor,
        object: object,
        to: to,
        context: nil
      }


      {:ok, activity} = ActivityPub.create(params) #|> IO.inspect(label: "AP activity")

      assert actor.data["id"] == activity.data["actor"]
      assert object["summary"] =~ activity.object.data["summary"]

      assert {:ok, event} = Bonfire.Federate.ActivityPub.Receiver.receive_activity(activity)
      # IO.inspect(event, label: "event created based on incoming AP")
      # event = event.economic_event

      assert object["summary"] =~ event.note

      assert object["id"] == Bonfire.Common.URIs.canonical_url(event)
      assert actor.data["id"] == Bonfire.Common.URIs.canonical_url(event.creator)
      assert object["receiver"]["id"] == Bonfire.Common.URIs.canonical_url(event.receiver.id)
      assert object["resourceConformsTo"]["id"] == Bonfire.Common.URIs.canonical_url(event.resource_conforms_to.id)
      assert object["resourceInventoriedAs"]["id"] == Bonfire.Common.URIs.canonical_url(event.resource_inventoried_as.id)
      assert object["toResourceInventoriedAs"]["id"] == Bonfire.Common.URIs.canonical_url(event.to_resource_inventoried_as.id)
      assert object["outputOf"]["id"] == Bonfire.Common.URIs.canonical_url(event.output_of.id)

      assert object["resourceQuantity"]["hasNumericalValue"] == event.resource_quantity.has_numerical_value
      # assert object["resourceQuantity"]["hasUnit"]["symbol"] == event.resource_quantity.unit.symbol

      # assert Bonfire.Boundaries.Circles.circles[:guest] in Bonfire.Social.FeedActivities.feeds_for_activity(post.activity)
    end
  end
end
