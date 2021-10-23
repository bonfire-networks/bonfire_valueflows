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
              "due" => "2021-10-27T18:28:24.908588Z",
              "finished" => true,
              "id" => "https://kawen.space/pub/objects/01FJQGYPE453WN811TZ1V11GSB",
              "name" => "Rogahn, Crooks and Kozey",
              "resourceClassifiedAs" => [],
              "summary" => "In rerum rem enim iure nihil odit et maiores voluptas.",
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
      # assert object["action"] == proposal.action_id
      assert actor.data["id"] == proposal |> Bonfire.Repo.maybe_preload(creator: [character: [:peered]]) |> Utils.e(:creator, :character, :peered, :canonical_uri, nil)

      # assert Bonfire.Boundaries.Circles.circles[:guest] in Bonfire.Social.FeedActivities.feeds_for_activity(post.activity)
    end

  end
end
