defmodule ValueFlows.Planning.Intent.FederateTest do
  use Bonfire.ValueFlows.DataCase
  alias Bonfire.Common.Utils
  import Bonfire.Common.Simulation
  import Bonfire.Geolocate.Simulate
  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  import Tesla.Mock

  setup do
    mock(fn
      %{method: :get, url: "https://kawen.space/users/karen"} ->
        json(Bonfire.Federate.ActivityPub.Simulate.actor_json("https://kawen.space/users/karen"))
    end)

    :ok
  end

  describe "intent" do
    test "federates/publishes an intent" do
      user = fake_agent!()

      unit = maybe_fake_unit(user)

      intent = fake_intent!(user, %{}, unit)

      assert {:ok, activity} = Bonfire.Federate.ActivityPub.Publisher.publish("create", intent)
      #IO.inspect(published: activity) ########

      assert activity.pointer_id == intent.id
      assert activity.local == true

      assert activity.data["object"]["name"] =~ intent.name
      # assert object["type"] == "ValueFlows:Offer"

    end

    test "creates an intent for a basic incoming need" do

      {:ok, actor} = ActivityPub.Actor.get_or_fetch_by_ap_id("https://kawen.space/users/karen")

      action = "produce"
      to = [
        "https://testing.kawen.dance/users/karen",
        "https://www.w3.org/ns/activitystreams#Public"
      ]

      object = %{
        "id" => "https://kawen.space/"<>Pointers.ULID.generate(),
        "name" => "title",
        "summary" => "content",
        "type" => "ValueFlows:Intent",
        "action" => action,
        "to" => to
      }

      params = %{
        actor: actor,
        object: object,
        to: to,
        context: nil
      }

      {:ok, activity} = ActivityPub.create(params) #|> IO.inspect

      assert actor.data["id"] == activity.data["actor"]
      assert object["summary"] =~ activity.data["object"]["summary"]

      assert {:ok, intent} = Bonfire.Federate.ActivityPub.Receiver.receive_activity(activity)
      # IO.inspect(intent: intent)
      assert object["name"] =~ intent.name
      assert object["summary"] =~ intent.note
      assert object["action"] == intent.action_id
      assert actor.data["id"] == intent |> Bonfire.Repo.maybe_preload(creator: [character: [:peered]]) |> Utils.e(:creator, :character, :peered, :canonical_uri, nil)

      # assert Bonfire.Boundaries.Circles.circles[:guest] in Bonfire.Social.FeedActivities.feeds_for_activity(post.activity)
    end

    test "creates an intent for an incoming need/offer with nested objects" do

      {:ok, actor} = ActivityPub.Actor.get_or_fetch_by_ap_id("https://kawen.space/users/karen")

      action = "work"
      to = [
        "https://testing.kawen.dance/users/karen",
        "https://www.w3.org/ns/activitystreams#Public"
      ]

      object = %{
        "action" => action,
        "availableQuantity" => %{
          "hasNumericalValue" => 0.1,
          "id" => "https://kawen.space/pub/objects/01FJNJV112NT76310KWRXJZWJ0",
          "type" => "om2:Measure",
          "hasUnit" => %{
            "id" => "https://kawen.space/pub/objects/01FMTXZV656FFKN0Y0BFPS57VA",
            "label" => "kilo",
            "symbol" => "kg",
            "type" => "om2:Unit"
          }
        },
        "due" => "2022-07-25T10:44:00.637055Z",
        # "effortQuantity" => %{
        #   "hasNumericalValue" => 0.2,
        #   "id" => "https://kawen.space/pub/objects/01FJNJV110K9T6212CV24W4VCA",
        #   "type" => "om2:Measure"
        # },
        "finished" => false,
        "id" => "https://kawen.space/pub/objects/01FJNJV113P04FBFM20P5VZVEA",
        "inScopeOf" => [],
        "name" => "Welch and Sons",
        "summary" => "Quisquam cupiditate et minus aut cupiditate in sit.",
        "publishedIn" => [],
        # "resourceClassifiedAs" => ["https://bonjour.bonfire.cafe/pub/actors/Needs_Offers"],
        # "resourceQuantity" => %{
        #   "hasNumericalValue" => 0.3,
        #   "id" => "https://kawen.space/pub/objects/01FJNJV1110VYYN8AT9PPVEJ0Q",
        #   "type" => "om2:Measure"
        # },
        "type" => "ValueFlows:Intent"
      }


      params = %{
        actor: actor,
        object: object,
        to: to,
        context: nil
      }

      {:ok, activity} = ActivityPub.create(params) #|> IO.inspect

      assert actor.data["id"] == activity.data["actor"]
      assert object["summary"] =~ activity.data["object"]["summary"]

      assert {:ok, intent} = Bonfire.Federate.ActivityPub.Receiver.receive_activity(activity)
      IO.inspect(intent, label: "intent created based on incoming AP")

      assert object["name"] =~ intent.name
      assert object["summary"] =~ intent.note
      assert object["action"] == intent.action_id

      assert object["id"] == Bonfire.Common.URIs.canonical_url(intent)
      assert actor.data["id"] == Bonfire.Common.URIs.canonical_url(intent.creator)

      assert object["availableQuantity"]["hasNumericalValue"] == intent.available_quantity.has_numerical_value
      assert object["availableQuantity"]["hasUnit"]["symbol"] == intent.available_quantity.unit.symbol
      assert object["availableQuantity"]["hasUnit"]["id"] == Bonfire.Common.URIs.canonical_url(intent.available_quantity.unit)

      # assert Bonfire.Boundaries.Circles.circles[:guest] in Bonfire.Social.FeedActivities.feeds_for_activity(post.activity)
    end

  end

end
