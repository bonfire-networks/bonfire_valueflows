defmodule ValueFlows.Proposal.FederateTest do
  use Bonfire.ValueFlows.DataCase

  alias Bonfire.Common.Utils
  import Bonfire.Common.Simulation
  import Bonfire.Geolocate.Simulate
  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  import Tesla.Mock

  @debug false
  @schema Bonfire.GraphQL.Schema

  setup do
    mock(fn
      %{method: :get, url: "https://kawen.space/users/karen"} ->
        json(Bonfire.Federate.ActivityPub.Simulate.actor_json("https://kawen.space/users/karen"))
    end)

    :ok
  end

  describe "proposal" do
    test "federates/publishes" do
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
      # TODO: check that intent creator/provider/receiver/action are included
    end

    test "creates a proposal/proposed_intent/proposal for incoming federation " do

      {:ok, actor} = ActivityPub.Actor.get_or_fetch_by_ap_id("https://kawen.space/users/karen")

      action = "work"
      to = [
        "https://testing.kawen.dance/users/karen",
        "https://www.w3.org/ns/activitystreams#Public"
      ]

      object = %{
        "actor" => "https://kawen.space/pub/actors/karen",
        "attributedTo" => "https://kawen.space/pub/actors/karen",
        "context" => [],
        "eligibleLocation" => %{
          "id" => "https://kawen.space/pub/objects/01FJQGYPB6N7XRWPBHDWGJC11N",
          "latitude" => -62.7021413680051,
          "longitude" => 49.090646966696994,
          "name" => "Graham, Padberg and Hahn",
          "summary" => "Nemo blanditiis molestias excepturi quis esse minima.",
          "type" => "Place"
        },
        "hasBeginning" => "2021-09-20T16:30:10.676375Z",
        "hasEnd" => "2022-08-02T20:28:38.097004Z",
        "id" => "https://kawen.space/pub/objects/01FJQGYPBH6G3D9F7DK5MN7C2A",
        "name" => "McGlynn-King",
        "published" => "2021-10-23T21:29:51.217969Z",
        "publishes" => [
          %{
            "id" => "https://kawen.space/pub/objects/01FJQGYPG9Q3HWG1BW2TS0FN86",
            "publishes" => %{
              "action" => "work",
              "provider" => "https://kawen.space/pub/actors/karen",
              # "availableQuantity" => %{
              #   "hasNumericalValue" => 0.6819459786798888,
              #   "id" => "http://localhost:4000/pub/objects/01FJQKZQXR0QX0PBG4EEAFGJMS",
              #   "type" => "ValueFlows:Measure"
              # },
              "context" => [],
              "due" => "2021-10-29T19:14:58.018729Z",
              # "effortQuantity" => %{
              #   "hasNumericalValue" => 0.6733462698502527,
              #   "id" => "http://localhost:4000/pub/objects/01FJQKZQXP0TZN6W0SDG1J0AJE",
              #   "type" => "ValueFlows:Measure"
              # },
              "finished" => true,
              "id" => "http://localhost:4000/pub/objects/01FJQKZQXSQN935N34ZVBK4ZED",
              "name" => "Leannon Group",
              "resourceClassifiedAs" => [],
              # "resourceQuantity" => %{
              #   "hasNumericalValue" => 0.9790977026822164,
              #   "id" => "http://localhost:4000/pub/objects/01FJQKZQXQ945QAGTP457TP16D",
              #   "type" => "ValueFlows:Measure"
              # },
              "summary" => "Et eligendi at maxime voluptate.",
              "tags" => [],
              "type" => "ValueFlows:Intent"
            },
            "reciprocal" => true,
            "type" => "ValueFlows:ProposedIntent"
          }
        ],
        "summary" => "Sunt consequatur quia modi vero corrupti animi ut natus voluptate!",
        "type" => "ValueFlows:Proposal"
      }


      params = %{
        actor: actor,
        object: object,
        to: to,
        context: nil
      }

      {:ok, activity} = ActivityPub.create(params) #|> IO.inspect

      assert actor.data["id"] == activity.data["actor"]
      assert object["summary"] == activity.data["object"]["summary"]

      assert {:ok, proposal} = Bonfire.Federate.ActivityPub.Receiver.receive_activity(activity)
      IO.inspect(proposal, label: "proposal created based on incoming AP")

      assert object["name"] == proposal.name
      assert object["summary"] == proposal.note
      assert actor.data["id"] == proposal |> Bonfire.Repo.maybe_preload(creator: [character: [:peered]]) |> Utils.e(:creator, :character, :peered, :canonical_uri, nil)

      assert p_intent_object = object["publishes"] |> List.first
      assert intent_object = p_intent_object["publishes"]

      assert p_intent = proposal.publishes |> List.first
      assert intent = p_intent.publishes

      assert intent_object["name"] == intent.name
      assert intent_object["action"] == intent.action_id

      # assert Bonfire.Boundaries.Circles.circles[:guest] in Bonfire.Social.FeedActivities.feeds_for_activity(post.activity)
    end

  end
end
