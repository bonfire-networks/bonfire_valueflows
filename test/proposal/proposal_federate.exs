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

    test "creates a basic proposal from an incoming federated activity " do

      {:ok, actor} = ActivityPub.Actor.get_or_fetch_by_ap_id("https://kawen.space/users/karen")

      action = "work"
      to = [
        "https://testing.kawen.dance/users/karen",
        "https://www.w3.org/ns/activitystreams#Public"
      ]

      object = %{
        "actor" => "https://kawen.space/users/karen",
        "attributedTo" => "https://kawen.space/users/karen",
        "context" => [],
        "hasBeginning" => "2021-09-20T16:30:10.676375Z",
        "hasEnd" => "2022-08-02T20:28:38.097004Z",
        "id" => "https://kawen.space/pub/objects/01FJQGYPBH6G3D9F7DK5MN7C2A",
        "name" => "McGlynn-King",
        "published" => "2021-10-23T21:29:51.217969Z",
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
      assert object["summary"] =~ activity.data["object"]["summary"]

      assert {:ok, proposal} = Bonfire.Federate.ActivityPub.Receiver.receive_activity(activity)
      # IO.inspect(proposal, label: "proposal created based on incoming AP")

      assert object["name"] =~ proposal.name
      assert object["summary"] =~ proposal.note
      assert actor.data["id"] == proposal |> Bonfire.Repo.maybe_preload(creator: [character: [:peered]]) |> Utils.e(:creator, :character, :peered, :canonical_uri, nil)

      # assert Bonfire.Boundaries.Circles.circles[:guest] in Bonfire.Social.FeedActivities.feeds_for_activity(post.activity)
    end

    test "creates a proposal with nested proposed_intent + intent from an incoming federated activity " do

      {:ok, actor} = ActivityPub.Actor.get_or_fetch_by_ap_id("https://kawen.space/users/karen")

      action = "work"
      to = [
        "https://testing.kawen.dance/users/karen",
        "https://www.w3.org/ns/activitystreams#Public"
      ]

      object = %{
        "actor" => "https://kawen.space/users/karen",
        "attributedTo" => "https://kawen.space/users/karen",
        "context" => [],
        "eligibleLocation" => %{
          "id" => "https://kawen.space/pub/objects/01FJQGYPB6N7XRWPBHDWGJC11N",
          "attributedTo" => "https://kawen.space/users/karen",
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
            "attributedTo" => "https://kawen.space/users/karen",
            "publishes" => %{
              "action" => "work",
              "provider" => "https://kawen.space/users/karen",
              # "availableQuantity" => %{
              #   "hasNumericalValue" => 0.6819459786798888,
              #   "id" => "https://kawen.space/pub/objects/01FJQKZQXR0QX0PBG4EEAFGJMS",
              #   "type" => "om2:Measure"
              # },
              "context" => [],
              "due" => "2021-10-29T19:14:58.018729Z",
              # "effortQuantity" => %{
              #   "hasNumericalValue" => 0.6733462698502527,
              #   "id" => "https://kawen.space/pub/objects/01FJQKZQXP0TZN6W0SDG1J0AJE",
              #   "type" => "om2:Measure"
              # },
              "finished" => true,
              "id" => "https://kawen.space/pub/objects/01FJQKZQXSQN935N34ZVBK4ZED",
              "name" => "Leannon Group",
              "resourceClassifiedAs" => [],
              # "resourceQuantity" => %{
              #   "hasNumericalValue" => 0.9790977026822164,
              #   "id" => "https://kawen.space/pub/objects/01FJQKZQXQ945QAGTP457TP16D",
              #   "type" => "om2:Measure"
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
      assert object["summary"] =~ activity.data["object"]["summary"]

      assert {:ok, proposal} = Bonfire.Federate.ActivityPub.Receiver.receive_activity(activity)
      IO.inspect(proposal, label: "proposal created based on incoming AP")

      assert object["name"] =~ proposal.name
      assert object["summary"] =~ proposal.note

      assert object["id"] == Bonfire.Common.URIs.canonical_url(proposal)
      assert actor.data["id"] == Bonfire.Common.URIs.canonical_url(proposal.creator)

      assert object["eligibleLocation"]["name"] =~ proposal.eligible_location.name
      assert object["eligibleLocation"]["id"] == Bonfire.Common.URIs.canonical_url(proposal.eligible_location)

      assert p_intent_object = object["publishes"] |> List.first
      assert intent_object = p_intent_object["publishes"]

      assert p_intent = proposal.publishes |> List.first
      assert the_intent = p_intent.publishes

      assert intent_object["id"] == Bonfire.Common.URIs.canonical_url(the_intent)
      assert intent_object["name"] =~ the_intent.name
      assert intent_object["action"] == the_intent.action_id

      # assert Bonfire.Boundaries.Circles.circles[:guest] in Bonfire.Social.FeedActivities.feeds_for_activity(post.activity)
    end


    test "creates a proposed_intent with nested proposal + intent from an incoming federated activity " do

      {:ok, actor} = ActivityPub.Actor.get_or_fetch_by_ap_id("https://kawen.space/users/karen")

      action = "work"
      to = [
        "https://testing.kawen.dance/users/karen",
        "https://www.w3.org/ns/activitystreams#Public"
      ]

      object = %{
          "id" => "https://kawen.space/pub/objects/01FJQGYPG9Q3HWG1BW2TS0FN86",
          "type" => "ValueFlows:ProposedIntent",
          "reciprocal" => true,
          "attributedTo" => "https://kawen.space/users/karen",
          "publishes" => %{
            "action" => "work",
            "provider" => "https://kawen.space/users/karen",
            # "availableQuantity" => %{
            #   "hasNumericalValue" => 0.6819459786798888,
            #   "id" => "https://kawen.space/pub/objects/01FJQKZQXR0QX0PBG4EEAFGJMS",
            #   "type" => "om2:Measure"
            # },
            "context" => [],
            "due" => "2021-10-29T19:14:58.018729Z",
            # "effortQuantity" => %{
            #   "hasNumericalValue" => 0.6733462698502527,
            #   "id" => "https://kawen.space/pub/objects/01FJQKZQXP0TZN6W0SDG1J0AJE",
            #   "type" => "om2:Measure"
            # },
            "finished" => true,
            "id" => "https://kawen.space/pub/objects/01FJQKZQXSQN935N34ZVBK4ZED",
            "name" => "Leannon Group",
            "resourceClassifiedAs" => [],
            # "resourceQuantity" => %{
            #   "hasNumericalValue" => 0.9790977026822164,
            #   "id" => "https://kawen.space/pub/objects/01FJQKZQXQ945QAGTP457TP16D",
            #   "type" => "om2:Measure"
            # },
            "summary" => "Et eligendi at maxime voluptate.",
            "tags" => [],
            "type" => "ValueFlows:Intent"
          },
          "publishedIn" => %{
            "actor" => "https://kawen.space/users/karen",
            "attributedTo" => "https://kawen.space/users/karen",
            "context" => [],
            "eligibleLocation" => %{
              "id" => "https://kawen.space/pub/objects/01FJQGYPB6N7XRWPBHDWGJC11N",
              # "attributedTo" => "https://kawen.space/users/karen",
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
            "summary" => "Sunt consequatur quia modi vero corrupti animi ut natus voluptate!",
            "type" => "ValueFlows:Proposal"
          }
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

      assert {:ok, p_intent} = Bonfire.Federate.ActivityPub.Receiver.receive_activity(activity)
      # IO.inspect(p_intent, label: "proposed intent created based on incoming AP")

      assert proposal = p_intent.published_in
      assert intent = p_intent.publishes

      assert object["reciprocal"] == true

      assert proposal_object = object["publishedIn"]
      assert intent_object = object["publishes"]

      assert proposal_object["name"] =~ proposal.name
      assert proposal_object["summary"] =~ proposal.note

      assert actor.data["id"] == proposal |> Bonfire.Repo.maybe_preload(creator: [character: [:peered]]) |> Utils.e(:creator, :character, :peered, :canonical_uri, nil)

      assert intent_object["name"] =~ intent.name
      assert intent_object["action"] == intent.action_id

      # assert Bonfire.Boundaries.Circles.circles[:guest] in Bonfire.Social.FeedActivities.feeds_for_activity(post.activity)
    end


    test "creates an intent with nested proposed_intent + proposal from an incoming federated activity " do

      {:ok, actor} = ActivityPub.Actor.get_or_fetch_by_ap_id("https://kawen.space/users/karen")

      action = "work"
      to = [
        "https://testing.kawen.dance/users/karen",
        "https://www.w3.org/ns/activitystreams#Public"
      ]

      object = %{
        "type" => "ValueFlows:Intent",
        "action" => "work",
        "provider" => "https://kawen.space/users/karen",
        # "availableQuantity" => %{
        #   "hasNumericalValue" => 0.6819459786798888,
        #   "id" => "https://kawen.space/pub/objects/01FJQKZQXR0QX0PBG4EEAFGJMS",
        #   "type" => "om2:Measure"
        # },
        "context" => [],
        "due" => "2021-10-29T19:14:58.018729Z",
        # "effortQuantity" => %{
        #   "hasNumericalValue" => 0.6733462698502527,
        #   "id" => "https://kawen.space/pub/objects/01FJQKZQXP0TZN6W0SDG1J0AJE",
        #   "type" => "om2:Measure"
        # },
        "finished" => true,
        "id" => "https://kawen.space/pub/objects/01FJQKZQXSQN935N34ZVBK4ZED",
        "name" => "Leannon Group",
        "resourceClassifiedAs" => [],
        # "resourceQuantity" => %{
        #   "hasNumericalValue" => 0.9790977026822164,
        #   "id" => "https://kawen.space/pub/objects/01FJQKZQXQ945QAGTP457TP16D",
        #   "type" => "om2:Measure"
        # },
        "summary" => "Et eligendi at maxime voluptate.",
        "tags" => [],
        "publishedIn" => [%{
          "id" => "https://kawen.space/pub/objects/01FJQGYPG9Q3HWG1BW2TS0FN86",
          "type" => "ValueFlows:ProposedIntent",
          "reciprocal" => true,
          "attributedTo" => "https://kawen.space/users/karen",
          "publishedIn" => %{
            "actor" => "https://kawen.space/users/karen",
            "attributedTo" => "https://kawen.space/users/karen",
            "context" => [],
            "eligibleLocation" => %{
              "id" => "https://kawen.space/pub/objects/01FJQGYPB6N7XRWPBHDWGJC11N",
              # "attributedTo" => "https://kawen.space/users/karen",
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
            "summary" => "Sunt consequatur quia modi vero corrupti animi ut natus voluptate!",
            "type" => "ValueFlows:Proposal"
          }
        }]
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

      assert p_intent = intent.published_in |> List.first
      assert proposal = p_intent.published_in

      assert p_intent_object = object["publishedIn"] |> List.first
      assert proposal_object = p_intent_object["publishedIn"]

      assert p_intent_object["reciprocal"] == true

      assert proposal_object["name"] =~ proposal.name
      assert proposal_object["summary"] =~ proposal.note

      assert actor.data["id"] == proposal |> Bonfire.Repo.maybe_preload(creator: [character: [:peered]]) |> Utils.e(:creator, :character, :peered, :canonical_uri, nil)

      assert object["name"] =~ intent.name
      assert object["action"] == intent.action_id

      # assert Bonfire.Boundaries.Circles.circles[:guest] in Bonfire.Social.FeedActivities.feeds_for_activity(post.activity)
    end
  end
end
