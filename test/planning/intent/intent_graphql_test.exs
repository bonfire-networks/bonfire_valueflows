defmodule ValueFlows.Planning.Intent.GraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  import Bonfire.Common.Simulation




  import Bonfire.Geolocate.Simulate
  import Bonfire.Geolocate.Test.Faking




  import ValueFlows.Simulate
  import ValueFlows.Test.Faking
  alias ValueFlows.Planning.Intent.Intents

  @debug false
  @schema Bonfire.GraphQL.Schema

  describe "intent" do
    test "fetches an existing intent by ID (via Graphql/HTTP)" do
      user = fake_agent!()
      intent = fake_intent!(user)

      q = intent_query()
      conn = user_conn(user)
      assert_intent(grumble_post_key(q, conn, :intent, %{id: intent.id}))
    end

    @tag :skip
    test "fetches a full nested intent by ID (via Absinthe.run)" do
      user = fake_agent!()

      location = fake_geolocation!(user)

      unit = maybe_fake_unit(user)

      parent = fake_agent!()

      intent = fake_intent!(user, %{
        provider: user.id,
        at_location: location,
        resource_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        effort_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        available_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        in_scope_of: [parent.id]
      })

      #IO.inspect(intent: intent)

      proposal = fake_proposal!(user)

      fake_proposed_intent!(proposal, intent)

      assert intent_queried =
               Bonfire.GraphQL.QueryHelper.run_query_id(
                 intent.id,
                 @schema,
                 :intent,
                 3,
                 nil,
                 @debug
               )

      assert_intent(intent_queried)
      assert_proposal(hd(intent_queried["publishedIn"])["publishedIn"])
      assert_geolocation(intent_queried["atLocation"])
      assert_agent(intent_queried["provider"])
      Bonfire.Quantify.Test.Faking.assert_measure(intent_queried["resourceQuantity"])
      Bonfire.Quantify.Test.Faking.assert_measure(intent_queried["availableQuantity"])
      Bonfire.Quantify.Test.Faking.assert_measure(intent_queried["effortQuantity"])
      assert hd(intent_queried["inScopeOf"])["__typename"] == "Person"
    end

    test "fails for deleted intent" do
      user = fake_agent!()
      intent = fake_intent!(user)
      assert {:ok, intent} = Intents.soft_delete(intent)

      q = intent_query()
      conn = user_conn(user)
      assert [%{"status" => 404}] = grumble_post_errors(q, conn, %{id: intent.id})
    end
  end

  describe "intent.publishedIn" do
    test "lists proposed intents for an intent" do
      user = fake_agent!()
      proposal = fake_proposal!(user)
      intent = fake_intent!(user)

      some(5, fn -> fake_proposed_intent!(proposal, intent) end)

      q = intent_query(fields: [publishedIn: [:id]])
      conn = user_conn(user)
      assert intent = grumble_post_key(q, conn, :intent, %{id: intent.id})
      assert Enum.count(intent["publishedIn"]) == 5
    end
  end

  describe "intent.publishedIn.publishes" do
    test "lists the intents for a proposed intent" do
      user = fake_agent!()
      proposal = fake_proposal!(user)
      intent = fake_intent!(user)

      some(5, fn -> fake_proposed_intent!(proposal, intent) end)

      q =
        intent_query(
          fields: [
            published_in: [:id, publishes: intent_fields()]
          ]
        )

      conn = user_conn(user)
      assert fetched = grumble_post_key(q, conn, :intent, %{id: intent.id})
      assert_intent(intent, fetched)
    end
  end

  describe "intent.inScopeOf" do
    test "returns the scope of the intent" do
      user = fake_agent!()
      parent = fake_agent!()
      intent = fake_intent!(user, %{in_scope_of: [parent.id]})

      q = intent_query(fields: [in_scope_of: [:__typename]])
      conn = user_conn(user)
      assert intent = grumble_post_key(q, conn, :intent, %{id: intent.id})
      assert hd(intent["inScopeOf"])["__typename"] == "Person"
    end
  end

  describe "intents" do
    test "fetches all items that are not deleted" do
      user = fake_agent!()
      intents = some(5, fn -> fake_intent!(user) end)
      # deleted
      some(2, fn ->
        intent = fake_intent!(user)
        {:ok, intent} = Intents.soft_delete(intent)
        intent
      end)

      q = intents_query()
      conn = user_conn(user)
      assert fetched_intents = grumble_post_key(q, conn, :intents, %{})
      assert Enum.count(intents) == Enum.count(fetched_intents)
    end
  end

  describe "intentsPages" do
    test "fetches all items that are not deleted" do
      user = fake_agent!()
      intents = some(5, fn -> fake_intent!(user) end)
      # deleted
      some(2, fn ->
        intent = fake_intent!(user)
        {:ok, intent} = Intents.soft_delete(intent)
        intent
      end)

      q = intents_pages_query()
      conn = user_conn(user)
      assert page = grumble_post_key(q, conn, :intents_pages, %{})
      assert Enum.count(intents) == page["totalCount"]
    end
  end

  describe "create_intent" do
    test "creates a new intent given valid attributes" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      q =
        create_intent_mutation(
          fields: [
            available_quantity: [:has_numerical_value, has_unit: [:id, :label]]
          ]
        )

      conn = user_conn(user)
      vars = %{intent: intent_input(%{
        "availableQuantity" => Bonfire.Quantify.Simulate.measure_input(unit),
      })}
      assert intent = grumble_post_key(q, conn, :create_intent, vars)["intent"]
      assert_intent(intent)

      assert intent["availableQuantity"]["hasNumericalValue"] ==
               vars.intent["availableQuantity"]["hasNumericalValue"]
    end

    test "creates a new offer given valid attributes" do
      user = fake_agent!()
      q = create_offer_mutation(fields: [provider: [:id]])
      conn = user_conn(user)
      vars = %{intent: intent_input()}
      assert intent = grumble_post_key(q, conn, :create_offer, vars)["intent"]
      assert_intent(intent)
      assert intent["provider"]["id"] == user.id
    end

    test "create a new need given valid attributes" do
      user = fake_agent!()
      q = create_need_mutation(fields: [receiver: [:id]])
      conn = user_conn(user)
      vars = %{intent: intent_input()}
      assert intent = grumble_post_key(q, conn, :create_need, vars)["intent"]
      assert_intent(intent)
      assert intent["receiver"]["id"] == user.id
    end

    test "creates a new intent given a scope" do
      user = fake_agent!()
      another_user = fake_agent!()

      q = create_intent_mutation(fields: [in_scope_of: [:__typename]])
      conn = user_conn(user)
      vars = %{intent: intent_input(%{"inScopeOf" => [another_user.id]})}
      assert intent = grumble_post_key(q, conn, :create_intent, vars)["intent"]
      assert_intent(intent)
      assert [context] = intent["inScopeOf"]
      assert context["__typename"] == "Person"
    end

    test "creates a new intent with a location" do
      user = fake_agent!()
      geo = fake_geolocation!(user)

      q = create_intent_mutation(fields: [at_location: [:id]])
      conn = user_conn(user)
      vars = %{intent: intent_input(%{"atLocation" => geo.id})}
      assert intent = grumble_post_key(q, conn, :create_intent, vars)["intent"]
      assert_intent(intent)
      assert intent["atLocation"]["id"] == geo.id
    end

    test "creates a new intent with an action" do
      user = fake_agent!()
      action = action()

      q = create_intent_mutation(fields: [action: [:id]])
      conn = user_conn(user)
      vars = %{intent: intent_input(%{"action" => action.id})}
      assert intent = grumble_post_key(q, conn, :create_intent, vars)["intent"]
      assert_intent(intent)
      assert intent["action"]["id"] == action.id
    end

    test "creates a new intent with a provider" do
      user = fake_agent!()
      provider = fake_agent!()

      q = create_intent_mutation(fields: [provider: [:id]])
      conn = user_conn(user)
      vars = %{intent: intent_input(%{"provider" => provider.id})}
      assert intent = grumble_post_key(q, conn, :create_intent, vars)["intent"]
      assert_intent(intent)
      assert intent["provider"]["id"] == provider.id
    end

    test "creates a new intent with a receiver" do
      user = fake_agent!()
      receiver = fake_agent!()

      q = create_intent_mutation(fields: [receiver: [:id]])
      conn = user_conn(user)
      vars = %{intent: intent_input(%{"receiver" => receiver.id})}
      assert intent = grumble_post_key(q, conn, :create_intent, vars)["intent"]
      assert_intent(intent)
      assert intent["receiver"]["id"] == receiver.id
    end

    test "creates a new intent with a provider and a receiver" do
      user = fake_agent!()
      provider = fake_agent!()
      receiver = fake_agent!()

      q = create_intent_mutation(fields: [receiver: [:id], provider: [:id]])
      conn = user_conn(user)

      vars = %{
        intent: intent_input(%{"receiver" => receiver.id, "provider" => provider.id})
      }

      assert intent = grumble_post_key(q, conn, :create_intent, vars)["intent"]
      assert_intent(intent)
      assert intent["receiver"]["id"] == receiver.id
      assert intent["provider"]["id"] == provider.id
    end

    test "creates a new intent with a url image" do
      user = fake_agent!()

      q = create_intent_mutation(fields: [:image])
      conn = user_conn(user)

      vars = %{
        intent:
          intent_input(%{"image" => "https://via.placeholder.com/150.png"})
      }

      assert intent = grumble_post_key(q, conn, :create_intent, vars)["intent"]
      assert_intent(intent)
      assert intent["image"] |> String.split_at(-4) |> elem(1) == ".png"
    end

    @tag :skip # FIXME
    test "create an intent with URIs as classification" do
      user = fake_agent!()

      tags = some(1..5, &url/0)

      q = create_intent_mutation(fields: [:resource_classified_as])
      conn = user_conn(user)

      vars = %{
        intent:
          intent_input(%{
            "resourceClassifiedAs" => tags
          })
      }

      assert intent = grumble_post_key(q, conn, :create_intent, vars)["intent"]

      assert_intent(intent)
      assert intent["resourceClassifiedAs"] == tags
    end

    test "create an intent with categories/tags" do
      user = fake_agent!()

      tags = some_fake_categories(user)

      q = create_intent_mutation(fields: [tags: [:__typename]])
      conn = user_conn(user)

      vars = %{
        intent:
          intent_input(%{
            "tags" => tags
          })
      }

      assert intent = grumble_post_key(q, conn, :create_intent, vars)["intent"]

      assert_intent(intent)
      assert hd(intent["tags"])["__typename"] == "Category"
    end

    test "fail if given an invalid action" do
      user = fake_agent!()
      _action = action()

      q = create_intent_mutation(fields: [action: [:id]])
      conn = user_conn(user)
      vars = %{intent: intent_input(%{"action" => "reading"})}
      assert [%{"field" => "action_id"}] = grumble_post_errors(q, conn, vars)
    end
  end

  describe "update_intent" do
    test "updates an existing intent" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)
      intent = fake_intent!(user)

      q = update_intent_mutation()
      conn = user_conn(user)
      vars = %{intent: intent_input(%{
        "id" => intent.id,
        "availableQuantity" => Bonfire.Quantify.Simulate.measure_input(unit),
      })}
      assert resp = grumble_post_key(q, conn, :update_intent, vars)["intent"]
      assert_intent(resp)

      assert {:ok, updated} = Intents.one(id: intent.id)
      assert updated != intent
      assert_intent(updated, resp)
      assert updated.available_quantity_id != intent.available_quantity_id
    end

    test "updates an existing intent with a scope" do
      user = fake_agent!()
      another_user = fake_agent!()
      intent = fake_intent!(user)

      q = update_intent_mutation(fields: [in_scope_of: [:__typename]])
      conn = user_conn(user)

      vars = %{
        intent:
          intent_input(%{
            "id" => intent.id,
            "inScopeOf" => [another_user.id]
          })
      }

      assert resp = grumble_post_key(q, conn, :update_intent, vars)["intent"]
      assert [context] = resp["inScopeOf"]
      assert context["__typename"] == "Person"
    end

    test "updates an existing intent with a location" do
      user = fake_agent!()
      geo = fake_geolocation!(user)
      intent = fake_intent!(user)

      q = update_intent_mutation(fields: [atLocation: [:id]])
      conn = user_conn(user)

      vars = %{
        intent:
          intent_input(%{
            "id" => intent.id,
            "atLocation" => geo.id
          })
      }

      assert resp = grumble_post_key(q, conn, :update_intent, vars)["intent"]
      assert resp["atLocation"]["id"] == geo.id
    end

    test "updates an existing intent with a url image" do
      user = fake_agent!()
      intent = fake_intent!(user)
      q = update_intent_mutation(fields: [:image])
      conn = user_conn(user)

      vars = %{
        intent:
          intent_input(%{
            "id" => intent.id,
            "image" => "https://via.placeholder.com/250.png"
          })
      }

      assert resp = grumble_post_key(q, conn, :update_intent, vars)["intent"]
      assert resp["image"] |> String.split_at(-4) |> elem(1) == ".png"
   end

    test "updates an existing intent with an action" do
      user = fake_agent!()
      intent = fake_intent!(user)

      q = update_intent_mutation(fields: [action: [:id]])
      conn = user_conn(user)

      action = action()
      vars = %{
        intent:
          intent_input(%{
            "id" => intent.id,
            "action" => action.id
          })
      }

      assert resp = grumble_post_key(q, conn, :update_intent, vars)["intent"]
      assert resp["action"]["id"] == action.id
    end

    @tag :skip
    test "fail if given an invalid action" do
      user = fake_agent!()
      intent = fake_intent!(user)
      _action = action()

      q = update_intent_mutation(fields: [action: [:id]])
      conn = user_conn(user)

      vars = %{
        intent:
          intent_input(%{
            "action" => "reading",
            "id" => intent.id
          })
      }

      assert [%{"status" => 404}] = grumble_post_errors(q, conn, vars)
    end
  end

  describe "delete_intent" do
    test "deletes an item that is not deleted" do
      user = fake_agent!()
      intent = fake_intent!(user)

      q = delete_intent_mutation()
      conn = user_conn(user)
      assert grumble_post_key(q, conn, :delete_intent, %{id: intent.id})
    end
  end
end
