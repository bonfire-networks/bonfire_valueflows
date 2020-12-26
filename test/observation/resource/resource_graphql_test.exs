defmodule ValueFlows.Observation.EconomicResource.GraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true


  import Bonfire.Common.Simulation





  import ValueFlows.Simulate
  import ValueFlows.Test.Faking
  # alias Grumble.PP
  alias ValueFlows.Observation.EconomicResource.EconomicResources

  import Bonfire.Geolocate.Simulate
  # import Bonfire.Geolocate.Test.Faking

  @debug false
  @schema Bonfire.GraphQL.Schema

  describe "EconomicResource" do
    test "fetches a basic economic resource by ID" do
      user = fake_agent!()
      resource = fake_economic_resource!(user)

      q = economic_resource_query()
      conn = user_conn(user)
      assert fetched = grumble_post_key(q, conn, :economic_resource, %{id: resource.id})
      assert_economic_resource(fetched)
    end

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

      # IO.inspect(created: resource)

      assert queried =
               Bonfire.GraphQL.QueryHelper.run_query_id(
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

      assert {:ok, spec} = EconomicResources.soft_delete(resource)

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

  describe "EconomicResources.track" do
    test "Returns a list of EconomicEvents that are inputs to Processes " do
      user = fake_agent!()
      resource = fake_economic_resource!(user)
      process = fake_process!(user)

      input_events =
        some(3, fn ->
          fake_economic_event!(user, %{
            input_of: process.id,
            resource_inventoried_as: resource.id,
            action: "use"
          })
        end)

      output_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            resource_inventoried_as: resource.id,
            action: "produce"
          })
        end)

      q = economic_resource_query(fields: [track: [:id]])
      conn = user_conn(user)

      assert resource = grumble_post_key(q, conn, :economic_resource, %{id: resource.id})
      assert Enum.count(resource["track"]) == 3
    end

    test "Returns a list of transfer/move EconomicEvents with the resource defined as the resourceInventoriedAs" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      resource = fake_economic_resource!(user, %{}, unit)

      input_events =
        some(3, fn ->
          fake_economic_event!(user, %{
            resource_inventoried_as: resource.id,
            action: "transfer"
          }, unit)
        end)

      _other_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            resource_inventoried_as: resource.id,
            action: "use"
          }, unit)
        end)

      q = economic_resource_query(fields: [track: [:id]])
      conn = user_conn(user)

      assert resource = grumble_post_key(q, conn, :economic_resource, %{id: resource.id})
      assert Enum.count(resource["track"]) == 3
    end
  end

  describe "EconomicResources.trace" do
    test "Returns a list of EconomicEvents affecting it that are outputs to Processes " do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      resource = fake_economic_resource!(user, %{}, unit)
      process = fake_process!(user)

      input_events =
        some(3, fn ->
          fake_economic_event!(user, %{
            input_of: process.id,
            resource_inventoried_as: resource.id,
            action: "use"
          }, unit)
        end)

      output_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            resource_inventoried_as: resource.id,
            action: "produce"
          }, unit)
        end)

      q = economic_resource_query(fields: [trace: [:id]])
      conn = user_conn(user)

      assert resource = grumble_post_key(q, conn, :economic_resource, %{id: resource.id})
      assert Enum.count(resource["trace"]) == 5
    end

    test "Returns a list of transfer/move EconomicEvents with the resource defined as the toResourceInventoriedAs" do
      alice = fake_agent!()
      bob = fake_agent!()

      unit = maybe_fake_unit(alice)

      resource = fake_economic_resource!(bob, %{}, unit)

      input_events =
        some(3, fn ->
          fake_economic_event!(alice, %{
            provider: alice.id,
            receiver: bob.id,
            to_resource_inventoried_as: resource.id,
            action: "transfer"
          }, unit)
        end)

      _other_events =
        some(5, fn ->
          fake_economic_event!(alice, %{
            provider: alice.id,
            receiver: bob.id,
            to_resource_inventoried_as: resource.id,
            action: "use"
          }, unit)
        end)

      q = economic_resource_query(fields: [trace: [:id]])

      conn = user_conn(alice)

      assert resource = grumble_post_key(q, conn, :economic_resource, %{id: resource.id})
      assert Enum.count(resource["trace"]) == 3
    end
  end
end
