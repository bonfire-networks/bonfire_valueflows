defmodule ValueFlows.EconomicResource.EconomicResourcesTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  import Bonfire.Common.Simulation

  import ValueFlows.Simulate

  import Bonfire.Geolocate.Simulate

  import ValueFlows.Test.Faking

  alias ValueFlows.EconomicResource.EconomicResources

  describe "one" do
    test "fetches an existing economic resource by ID" do
      user = fake_agent!()
      resource = fake_economic_resource!(user)
      assert {:ok, fetched} = EconomicResources.one(id: resource.id)
      assert_economic_resource(fetched)
      assert {:ok, fetched} = EconomicResources.one(user: user)
      assert_economic_resource(fetched)
    end
  end

  describe "create" do
    test "can create an economic resource" do
      user = fake_agent!()

      assert {:ok, resource} = EconomicResources.create(user, economic_resource())

      assert_economic_resource(resource)
    end

    test "can create an economic resource with current_location" do
      user = fake_agent!()
      location = fake_geolocation!(user)

      attrs = %{
        current_location: location.id
      }

      assert {:ok, resource} = EconomicResources.create(user, economic_resource(attrs))

      assert_economic_resource(resource)
      assert resource.current_location.id == attrs.current_location
    end

    test "can create an economic resource with conforms_to" do
      user = fake_agent!()

      attrs = %{
        conforms_to: fake_resource_specification!(user).id
      }

      assert {:ok, resource} = EconomicResources.create(user, economic_resource(attrs))

      assert_economic_resource(resource)
      assert resource.conforms_to.id == attrs.conforms_to
    end

    test "can create an economic resource with contained_in" do
      user = fake_agent!()

      attrs = %{
        contained_in: fake_economic_resource!(user).id
      }

      assert {:ok, resource} = EconomicResources.create(user, economic_resource(attrs))

      assert_economic_resource(resource)
      assert resource.contained_in.id == attrs.contained_in
    end

    test "can create an economic resource with primary_accountable" do
      user = fake_agent!()
      owner = fake_agent!()

      attrs = %{
        primary_accountable: owner.id
      }

      assert {:ok, resource} = EconomicResources.create(user, economic_resource(attrs))

      assert_economic_resource(resource)
      assert resource.primary_accountable.id == attrs.primary_accountable
    end

    test "can create an economic resource with accounting_quantity and onhand_quantity" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      attrs = %{
        accounting_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        onhand_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id})
      }

      assert {:ok, resource} = EconomicResources.create(user, economic_resource(attrs))

      assert_economic_resource(resource)
      assert resource.onhand_quantity.id
      assert resource.accounting_quantity.id
    end

    test "can create an economic resource with unit_of_effort" do
      user = fake_agent!()

      attrs = %{
        unit_of_effort: maybe_fake_unit(user).id
      }

      assert {:ok, resource} = EconomicResources.create(user, economic_resource(attrs))

      assert_economic_resource(resource)
      assert resource.unit_of_effort.id === attrs.unit_of_effort
    end
  end

  describe "update" do
    test "update an existing resource" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)
      resource = fake_economic_resource!(user)

      attrs = %{
        accounting_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        onhand_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id})
      }

      assert {:ok, updated} = EconomicResources.update(resource, economic_resource(attrs))

      assert_economic_resource(updated)
      assert resource != updated
      assert resource.accounting_quantity_id != updated.accounting_quantity_id
      assert resource.onhand_quantity_id != updated.onhand_quantity_id
    end
  end

  describe "soft delete" do
    test "delete an existing resource" do
      user = fake_agent!()
      spec = fake_economic_resource!(user)

      refute spec.deleted_at
      assert {:ok, spec} = EconomicResources.soft_delete(spec)
      assert spec.deleted_at
    end
  end
end
