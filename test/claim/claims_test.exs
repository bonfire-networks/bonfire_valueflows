defmodule ValueFlows.Claim.ClaimsTest do
  use Bonfire.ValueFlows.DataCase, async: true

  # import Bonfire.Common.Simulation

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.Claim.Claims

  describe "one" do
    test "by id" do
      claim = fake_claim!(fake_agent!())

      assert {:ok, fetched} = Claims.one(id: claim.id)
      assert_claim(fetched)
      assert claim.id == fetched.id
    end

    test "by action" do
      action_id = action_id()
      claim = fake_claim!(fake_agent!(), %{action: action_id})

      assert {:ok, fetched} = Claims.one(action_id: action_id)
      assert_claim(fetched)
      assert claim.action_id == fetched.action_id
    end

    test "by user" do
      user = fake_agent!()
      claim = fake_claim!(user)

      assert {:ok, fetched} = Claims.one(creator: user)
      assert_claim(fetched)
      assert claim.id == fetched.id
      assert claim.creator_id == fetched.creator_id
    end

    test "by provider" do
      user = fake_agent!()
      provider = fake_agent!()
      receiver = fake_agent!()
      claim = fake_claim!(user, provider, receiver)

      assert {:ok, fetched} = Claims.one(provider_id: provider.id)
      assert_claim(fetched)
      assert claim.id == fetched.id
      assert claim.provider_id == fetched.provider_id
    end

    test "by receiver" do
      user = fake_agent!()
      provider = fake_agent!()
      receiver = fake_agent!()
      claim = fake_claim!(user, provider, receiver)

      assert {:ok, fetched} = Claims.one(receiver_id: receiver.id)
      assert_claim(fetched)
      assert claim.id == fetched.id
      assert claim.receiver_id == fetched.receiver_id
    end

    test "by context" do
      user = fake_agent!()
      context = fake_agent!()
      claim = fake_claim!(user, %{in_scope_of: [context.id]})

      assert {:ok, fetched} = Claims.one(context_id: context.id)
      assert_claim(fetched)
      assert claim.id == fetched.id
      assert claim.context_id == fetched.context_id
    end

    test "default filter handles deleted items" do
      claim = fake_claim!(fake_agent!())

      assert {:ok, claim} = Claims.soft_delete(claim)
      assert {:error, :not_found} = Claims.one([:default, id: claim.id])
    end
  end

  describe "many" do
  end

  describe "create" do
    test "with only required parameters" do
      user = fake_agent!()
      provider = fake_agent!()
      receiver = fake_agent!()

      assert {:ok, claim} = Claims.create(user, provider, receiver, claim())
      assert_claim(claim)
      assert claim.creator.id == user.id
      assert claim.provider.id == provider.id
      assert claim.receiver.id == receiver.id
    end

    test "with a context" do
      user = fake_agent!()
      provider = fake_agent!()
      receiver = fake_agent!()

      attrs = %{
        in_scope_of: [fake_agent!().id]
      }

      assert {:ok, claim} = Claims.create(user, provider, receiver, claim(attrs))

      assert_claim(claim)
      assert claim.context.id == hd(attrs.in_scope_of)
    end

    test "with measure quantities" do
      user = fake_agent!()
      provider = fake_agent!()
      receiver = fake_agent!()

      unit = maybe_fake_unit(user)

      attrs = %{
        resource_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        effort_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id})
      }

      assert {:ok, claim} = Claims.create(user, provider, receiver, claim(attrs))

      assert_claim(claim)
      assert claim.resource_quantity.id
      assert claim.effort_quantity.id
    end

    test "with a resource specification" do
      user = fake_agent!()
      provider = fake_agent!()
      receiver = fake_agent!()

      attrs = %{
        resource_conforms_to: fake_resource_specification!(user).id
      }

      assert {:ok, claim} = Claims.create(user, provider, receiver, claim(attrs))

      assert_claim(claim)
      assert claim.resource_conforms_to.id == attrs.resource_conforms_to
    end

    test "with a triggered by event" do
      user = fake_agent!()
      provider = fake_agent!()
      receiver = fake_agent!()

      attrs = %{
        triggered_by: fake_economic_event!(user).id
      }

      assert {:ok, claim} = Claims.create(user, provider, receiver, claim(attrs))

      assert_claim(claim)
      assert claim.triggered_by.id == attrs.triggered_by
    end
  end

  describe "update" do
    test "can update an existing claim" do
      user = fake_agent!()
      claim = fake_claim!(user)

      assert {:ok, updated} = Claims.update(claim, claim())
      assert_claim(updated)
      assert updated.id == claim.id
      assert updated != claim
    end

    test "with a context" do
      user = fake_agent!()
      claim = fake_claim!(user)
      context = fake_agent!()

      assert {:ok, updated} = Claims.update(claim, %{in_scope_of: [context.id]})
      assert_claim(updated)
      assert updated.context.id == context.id
    end

    test "with measure quantities" do
      user = fake_agent!()
      claim = fake_claim!(user)

      unit = maybe_fake_unit(user)

      attrs = %{
        resource_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        effort_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id})
      }

      assert {:ok, updated} = Claims.update(claim, attrs)
      assert_claim(updated)
      assert updated.resource_quantity.id
      assert updated.effort_quantity.id
    end

    test "with a resource specification" do
      user = fake_agent!()
      claim = fake_claim!(user)

      attrs = %{
        resource_conforms_to: fake_resource_specification!(user).id
      }

      assert {:ok, updated} = Claims.update(claim, attrs)
      assert_claim(updated)
      assert attrs.resource_conforms_to == updated.resource_conforms_to.id
    end

    test "with a triggered by event" do
      user = fake_agent!()
      claim = fake_claim!(user)

      attrs = %{
        triggered_by: fake_economic_event!(user).id
      }

      assert {:ok, updated} = Claims.update(claim, attrs)
      assert_claim(updated)
      assert attrs.triggered_by == updated.triggered_by.id
    end
  end

  describe "soft_delete" do
    test "can delete an existing claim" do
      claim = fake_claim!(fake_agent!())

      refute claim.deleted_at
      assert {:ok, claim} = Claims.soft_delete(claim)
      assert claim.deleted_at
    end

    test "fails if the claim doesn't exist" do
      claim = fake_claim!(fake_agent!())

      assert {:ok, claim} = Claims.soft_delete(claim)
      assert {:error, _} = Claims.soft_delete(claim)
    end
  end
end
