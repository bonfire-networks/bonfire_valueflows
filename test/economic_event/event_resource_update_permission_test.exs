defmodule ValueFlows.EconomicEvent.EventResourceUpdatePermissionTest do
  @moduledoc """
  An event's effects on a resource that has no quantity yet set one on it, which is an update of the RESOURCE. So it is checked as the person creating the event against the resource, not taken as covered by the check the event itself passed: someone accountable for a resource and involved in the event, who may not update the resource, gets an error and the resource is left as it was.
  """
  use Bonfire.ValueFlows.DataCase, async: true

  import ValueFlows.Simulate

  alias ValueFlows.EconomicEvent.EconomicEvents
  alias ValueFlows.EconomicResource.EconomicResources

  # a resource with no quantity set, made by `owner`, with `accountable` accountable for it
  defp bare_resource!(owner, accountable \\ nil) do
    {:ok, resource} =
      EconomicResources.create(
        owner,
        economic_resource(%{primary_accountable: accountable && accountable.id})
      )

    resource
  end

  defp raise_event(user, resource) do
    unit = maybe_fake_unit(user)

    EconomicEvents.create(
      user,
      economic_event(%{
        action: "raise",
        resource_inventoried_as: resource.id,
        resource_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id})
      })
    )
  end

  defp accounting_quantity_id(resource) do
    {:ok, resource} = EconomicResources.one(id: resource.id)
    resource.accounting_quantity_id
  end

  defp onhand_value(resource) do
    {:ok, resource} = EconomicResources.one(id: resource.id)
    {:ok, measure} = Bonfire.Quantify.Measures.one(id: resource.onhand_quantity_id)
    measure.has_numerical_value
  end

  defp consume_event(user, provider, resource, unit) do
    EconomicEvents.create(
      user,
      economic_event(%{
        action: "consume",
        provider: provider.id,
        receiver: user.id,
        resource_inventoried_as: resource.id,
        resource_quantity:
          Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id, has_numerical_value: 1})
      })
    )
  end

  test "an event naming oneself as receiver can't lower the quantity of someone else's resource" do
    owner = fake_agent!()
    other = fake_agent!()
    unit = maybe_fake_unit(owner)
    resource = fake_economic_resource!(owner, %{}, unit)
    before = onhand_value(resource)

    refute ValueFlows.Util.can?(other, resource) == :ok,
           "control: they may not update the resource"

    assert {:error, _} = consume_event(other, owner, resource, unit)
    assert onhand_value(resource) == before

    # control: the owner's own event lowers it
    assert {:ok, _} = consume_event(owner, owner, resource, unit)
    assert onhand_value(resource) == before - 1
  end

  test "the owner's event sets the quantity on their resource (control)" do
    owner = fake_agent!()
    resource = bare_resource!(owner)
    assert is_nil(accounting_quantity_id(resource)), "control: it has no quantity yet"

    assert {:ok, _} = raise_event(owner, resource)
    refute is_nil(accounting_quantity_id(resource))
  end

  test "someone who is accountable for it but may not update it leaves it as it was" do
    owner = fake_agent!()
    accountable = fake_agent!()
    resource = bare_resource!(owner, accountable)

    refute ValueFlows.Util.can?(accountable, resource) == :ok,
           "control: they may not update the resource"

    assert {:error, _} = raise_event(accountable, resource)
    assert is_nil(accounting_quantity_id(resource))
  end
end
