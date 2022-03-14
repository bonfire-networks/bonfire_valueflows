defmodule ValueFlows.EconomicResource.GraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  import Bonfire.Common.Simulation

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking
  # alias Grumble.PP
  alias ValueFlows.EconomicResource.EconomicResources

  import Bonfire.Geolocate.Simulate
  # import Bonfire.Geolocate.Test.Faking

  @debug false
  @schema Bonfire.API.GraphQL.Schema

  describe "EconomicResource" do
    test "fetches a basic economic resource by ID" do
      user = fake_agent!()
      resource = fake_economic_resource!(user)

      q = economic_resource_query()
      conn = user_conn(user)
      assert fetched = grumble_post_key(q, conn, :economic_resource, %{id: resource.id})
      assert_economic_resource(fetched)
    end

    @tag :skip
    test "fetches a full nested economic resource by ID (via Absinthe.run)" do
      user = fake_agent!()

      location = fake_geolocation!(user)
      owner = fake_agent!()
      unit = maybe_fake_unit(user)

      attrs = %{
        current_location: location.id,
        conforms_to: fake_resource_specification!(user).id,
        contained_in: fake_economic_resource!(user).id,
        primary_accountable: owner.id,
        accounting_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        onhand_quantity: Bonfire.Quantify.Simulate.measure(%{unit_id: unit.id}),
        unit_of_effort: maybe_fake_unit(user).id
      }

      assert {:ok, resource} = EconomicResources.create(user, economic_resource(attrs))
      assert_economic_resource(resource)

      #IO.inspect(created: resource)

      assert queried =
               Bonfire.API.GraphQL.QueryHelper.run_query_id(
                 resource.id,
                 @schema,
                 :economic_resource,
                 4,
                 nil,
                 @debug
               )

      assert_economic_resource(queried)
    end

    test "fail if has been deleted" do
      user = fake_agent!()
      resource = fake_economic_resource!(user)

      q = economic_resource_query()
      conn = user_conn(user)

      assert {:ok, _spec} = EconomicResources.soft_delete(resource)

      assert [%{"code" => "not_found", "path" => ["economicResource"], "status" => 404}] =
               grumble_post_errors(q, conn, %{id: resource.id})
    end
  end

  describe "EconomicResources" do
    test "return a list of economicResources" do
      user = fake_agent!()
      resources = some(5, fn -> fake_economic_resource!(user) end)
      # deleted
      some(2, fn ->
        resource = fake_economic_resource!(user)
        {:ok, resource} = EconomicResources.soft_delete(resource)
        resource
      end)

      q = economic_resources_query()
      conn = user_conn(user)

      assert fetched_economic_resources = grumble_post_key(q, conn, :economic_resources, %{})
      assert Enum.count(resources) == Enum.count(fetched_economic_resources)
    end
  end

  describe "EconomicResourcesPages" do
    test "return a list of economicResources" do
      user = fake_agent!()
      resources = some(5, fn -> fake_economic_resource!(user) end)
      # deleted
      some(2, fn ->
        resource = fake_economic_resource!(user)
        {:ok, resource} = EconomicResources.soft_delete(resource)
        resource
      end)
      after_resource = List.first(resources)

      q = economic_resources_pages_query()
      conn = user_conn(user)
      vars = %{after: after_resource.id, limit: 2}

      assert page = grumble_post_key(q, conn, :economic_resources_pages, vars)
      assert Enum.count(resources) == page["totalCount"]
      assert List.first(page["edges"])["id"] == after_resource.id

    end
  end

end
