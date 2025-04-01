defmodule ValueFlows.EconomicEvent.EconomicEventsTest do
  use Bonfire.ValueFlows.DataCase, async: true

  import Bonfire.Common.Simulation

  import ValueFlows.Simulate

  import Bonfire.Geolocate.Simulate

  import ValueFlows.Test.Faking

  alias ValueFlows.EconomicEvent.EconomicEvents

  describe "one" do
    test "fetches an existing economic event by ID" do
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

      assert {:ok, fetched} = EconomicEvents.one(id: event.id)
      assert_economic_event(fetched)
      assert {:ok, fetched} = EconomicEvents.one(user: user)
      assert_economic_event(fetched)
    end
  end

  describe "create" do
    test "can create an economic event" do
      user = fake_agent!()
      provider = fake_agent_from_user!(user)
      receiver = fake_agent!()
      action = action()

      assert {:ok, %{economic_event: event}} =
               EconomicEvents.create(
                 user,
                 economic_event(%{
                   provider: provider.id,
                   receiver: receiver.id,
                   action: action.id
                 })
               )

      assert_economic_event(event)
      assert event.provider.id == provider.id
      assert event.receiver.id == receiver.id
      assert event.action.label == action.label
      assert event.creator.id == user.id
    end

    test "cannot create an economic event as someone else" do
      user = fake_agent!()
      provider = fake_agent!()
      receiver = fake_agent!()
      action = action()

      assert {:error, _e} =
               EconomicEvents.create(
                 user,
                 economic_event(%{
                   provider: provider.id,
                   receiver: receiver.id,
                   action: action.id
                 })
               )
    end

    test "can create an economic event with context" do
      user = fake_agent!()

      attrs = %{
        in_scope_of: [fake_agent!().id]
      }

      assert {:ok, %{economic_event: event}} = EconomicEvents.create(user, economic_event(attrs))

      assert_economic_event(event)
      assert event.context.id == hd(attrs.in_scope_of)
    end

    test "can create an economic event with tags" do
      user = fake_agent!()

      tags = some_fake_categories(user)
      attrs = %{tags: tags}

      assert {:ok, %{economic_event: event}} = EconomicEvents.create(user, economic_event(attrs))

      assert_economic_event(event)

      event = repo().preload(event, :tags)
      assert Enum.count(event.tags) == Enum.count(tags)
    end

    test "can create an economic event with input_of and output_of" do
      user = fake_agent!()

      attrs = %{
        input_of: fake_process!(user).id,
        output_of: fake_process!(user).id
      }

      assert {:ok, %{economic_event: event}} = EconomicEvents.create(user, economic_event(attrs))

      assert_economic_event(event)
      assert event.input_of.id == attrs.input_of
      assert event.output_of.id == attrs.output_of
    end

    test "can create an economic event with resource_inventoried_as" do
      user = fake_agent!()

      attrs = %{
        resource_inventoried_as: fake_economic_resource!(user).id
      }

      assert {:ok, %{economic_event: event}} = EconomicEvents.create(user, economic_event(attrs))

      assert_economic_event(event)
      assert event.resource_inventoried_as.id == attrs.resource_inventoried_as
    end

    test "can create an economic event with to_resource_inventoried_as" do
      user = fake_agent!()

      attrs = %{
        to_resource_inventoried_as: fake_economic_resource!(user).id
      }

      assert {:ok, %{economic_event: event}} = EconomicEvents.create(user, economic_event(attrs))

      assert_economic_event(event)

      assert event.to_resource_inventoried_as.id ==
               attrs.to_resource_inventoried_as
    end

    test "can create an economic event with resource_inventoried_as and to_resource_inventoried_as" do
      user = fake_agent!()

      attrs = %{
        resource_inventoried_as: fake_economic_resource!(user).id,
        to_resource_inventoried_as: fake_economic_resource!(user).id
      }

      assert {:ok, %{economic_event: event}} = EconomicEvents.create(user, economic_event(attrs))

      assert_economic_event(event)
      assert event.resource_inventoried_as.id == attrs.resource_inventoried_as

      assert event.to_resource_inventoried_as.id ==
               attrs.to_resource_inventoried_as
    end

    test "can create an economic event with resource_conforms_to" do
      user = fake_agent!()

      attrs = %{
        resource_conforms_to: fake_resource_specification!(user).id
      }

      assert {:ok, %{economic_event: event}} = EconomicEvents.create(user, economic_event(attrs))

      assert_economic_event(event)
      assert event.resource_conforms_to.id == attrs.resource_conforms_to
    end

    @tag :skip
    test "can create an economic event with URI in resource_classified_as" do
      user = fake_agent!()

      attrs = %{
        resource_classified_as: some(1..5, &url/0)
      }

      assert {:ok, %{economic_event: event}} = EconomicEvents.create(user, economic_event(attrs))

      assert_economic_event(event)
      assert event.resource_classified_as == attrs.resource_classified_as
    end

    test "can create an economic event with resource_quantity and effort_quantity" do
      user = fake_agent!()

      unit = maybe_fake_unit(user)

      measures = %{
        resource_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        effort_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id})
      }

      assert {:ok, %{economic_event: event}} =
               EconomicEvents.create(user, economic_event(measures))

      assert_economic_event(event)
      assert event.resource_quantity.id
      assert event.effort_quantity.id
    end

    test "can create an economic event, creating undefined units on the fly" do
      user = fake_agent!()

      unit = maybe_fake_unit(user)

      measures = %{
        resource_quantity: Bonfire.Quantify.Simulate.measure(%{has_unit: "kilo_joules"}),
        effort_quantity: Bonfire.Quantify.Simulate.measure(%{has_unit: "kilo_joules"})
      }

      assert {:ok, %{economic_event: event}} =
               EconomicEvents.create(user, economic_event(measures))

      assert_economic_event(event)
      assert event.resource_quantity.id
      assert event.effort_quantity.id
    end

    test "can create an economic event with location" do
      user = fake_agent!()

      location = fake_geolocation!(user)

      attrs = %{
        at_location: location.id
      }

      assert {:ok, %{economic_event: event}} = EconomicEvents.create(user, economic_event(attrs))

      assert_economic_event(event)
      assert event.at_location.id == attrs.at_location
    end

    test "can create an economic event triggered_by another event" do
      user = fake_agent!()

      triggered_by = fake_economic_event!(user)

      attrs = %{
        triggered_by: triggered_by.id
      }

      assert {:ok, %{economic_event: event}} = EconomicEvents.create(user, economic_event(attrs))

      assert_economic_event(event)
      assert event.triggered_by.id == attrs.triggered_by
    end
  end

  describe "update" do
    test "updates an existing event" do
      user = fake_agent!()
      economic_event = fake_economic_event!(user)

      assert {:ok, updated} =
               EconomicEvents.update(
                 user,
                 economic_event,
                 economic_event(%{note: "test"})
               )

      assert_economic_event(updated)
      assert economic_event != updated
    end

    test "cannot update somebody else's event" do
      alice = fake_agent!()
      bob = fake_agent!()
      economic_event = fake_economic_event!(alice)

      assert {:error, _e} =
               EconomicEvents.update(
                 bob,
                 economic_event,
                 economic_event(%{note: "test"})
               )
    end
  end

  describe "soft delete" do
    test "delete an existing event" do
      user = fake_agent!()
      spec = fake_economic_event!(user)

      refute spec.deleted_at
      assert {:ok, spec} = EconomicEvents.soft_delete(spec)
      assert spec.deleted_at
    end
  end
end
