# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Planning.Intent.IntentsTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  # import Bonfire.Common.Simulation

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.Planning.Intent.Intents

  describe "one" do
    test "fetches an existing intent by ID" do
      user = fake_agent!()
      intent = fake_intent!(user)

      assert {:ok, fetched} = Intents.one(id: intent.id)
      assert_intent(intent, fetched)
      assert {:ok, fetched} = Intents.one(user: user)
      assert_intent(intent, fetched)
      # TODO
      # assert {:ok, fetched} = Intents.one(context: comm)
    end
  end

  describe "create" do
    test "can create an intent" do
      user = fake_agent!()

      assert {:ok, intent} = Intents.create(user, intent())
      assert_intent(intent)
    end

    test "can create an intent with measure" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      measures = %{
        resource_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        effort_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        available_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id})
      }

      assert {:ok, intent} = Intents.create(user, intent(measures))
      assert_intent(intent)
    end

    test "can create an intent with provider and receiver" do
      user = fake_agent!()

      attrs = %{
        provider: fake_agent!().id
      }

      assert {:ok, intent} = Intents.create(user, intent(attrs))
      assert intent.provider_id == attrs.provider

      attrs = %{
        receiver: fake_agent!().id
      }

      assert {:ok, intent} = Intents.create(user, intent(attrs))
      assert intent.receiver_id == attrs.receiver

      attrs = %{
        receiver: fake_agent!().id,
        provider: fake_agent!().id
      }

      assert {:ok, intent} = Intents.create(user, intent(attrs))
      assert intent.receiver_id == attrs.receiver
      assert intent.provider_id == attrs.provider
    end

    test "can create an intent with a context" do
      user = fake_agent!()
      context = fake_agent!()

      attrs = %{in_scope_of: [context.id]}

      assert {:ok, intent} = Intents.create(user, intent(attrs))
      assert_intent(intent)
      assert intent.context.id == context.id
    end

    test "can create an intent with tags" do
      user = fake_agent!()
      tags = some_fake_categories(user)

      attrs = intent(%{tags: tags})
      assert {:ok, intent} = Intents.create(user, attrs)
      assert_intent(intent)
      intent = repo().preload(intent, :tags)
      assert Enum.count(intent.tags) == Enum.count(tags)
    end
  end

  describe "update" do
    test "updates an existing intent" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)
      intent = fake_intent!(user)

      measures = %{
        resource_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        # don't update one of them
        # effort_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        available_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id})
      }

      assert {:ok, updated} = Intents.update(intent, intent(measures))
      assert_intent(updated)
      assert intent != updated
      assert intent.effort_quantity_id == updated.effort_quantity_id
      assert intent.resource_quantity_id != updated.resource_quantity_id
      assert intent.available_quantity_id != updated.available_quantity_id
    end

    test "fails if we don't have permission" do
      user = fake_agent!()
      random = fake_agent!()
      intent = fake_intent!(user)

      assert {:error, :not_permitted} =
               Intents.update(random, intent, intent(%{note: "i can hackz?"}))
    end

    test "doesn't update if invalid action is given" do
      user = fake_agent!()
      intent = fake_intent!(user)

      assert {:ok, %{action: action}} =
               Intents.update(intent, intent(%{action: "sleeping"}))
      assert action == intent.action
    end
  end
end
