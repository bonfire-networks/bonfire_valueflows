defmodule ValueFlows.EconomicEvent.FederateTest do
  use Bonfire.ValueFlows.DataCase
  alias Bonfire.Common.Utils
  import Bonfire.Common.Simulation
  import Bonfire.Geolocate.Simulate
  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  @debug false
  @schema Bonfire.GraphQL.Schema

  import Tesla.Mock

  setup do
    mock(fn
      %{method: :get, url: "https://kawen.space/users/karen"} ->
        json(Bonfire.Federate.ActivityPub.Simulate.actor_json("https://kawen.space/users/karen"))
    end)

    :ok
  end

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

      assert activity.data["object"]["summary"] =~ event.note
    end
  end

  test "creates an economic event from an incoming federated activity " do

      {:ok, actor} = ActivityPub.Actor.get_or_fetch_by_ap_id("https://kawen.space/users/karen")

      to = [
        "https://testing.kawen.dance/users/karen",
        "https://www.w3.org/ns/activitystreams#Public"
      ]

      object = %{
        "action" => "https://w3id.org/valueflows#consume",
        "actor" => "https://kawen.space/users/karen",
        "attributedTo" => "https://kawen.space/users/karen",
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
          "id" => "https://kawen.space/users/karen",
          "name" => "Dr. Annalise Hane",
          "preferredUsername" => "orland_ward",
          "summary" => "Quasi vitae repudiandae et est enim minus aut vero repudiandae.",
          "type" => "Person"
        },
        "published" => "2021-11-06T03:39:50.790006Z",
        "receiver" => %{
          "agentType" => "Person",
          "id" => "https://kawen.space/users/karen",
          "name" => "Dr. Annalise Hane",
          "preferredUsername" => "orland_ward",
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
          "primaryAccountable" => "https://kawen.space/users/karen",
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
          "primaryAccountable" => "https://kawen.space/users/karen",
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
      assert object["summary"] =~ activity.data["object"]["summary"]

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
