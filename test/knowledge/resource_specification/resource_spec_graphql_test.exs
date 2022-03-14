defmodule ValueFlows.Knowledge.ResourceSpecification.GraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true


  # import Bonfire.Common.Simulation


  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.Knowledge.ResourceSpecification.ResourceSpecifications

  @debug false
  @schema Bonfire.API.GraphQL.Schema

  describe "resourceSpecification" do
    test "fetches a resource specification by ID" do
      user = fake_agent!()
      spec = fake_resource_specification!(user)

      q = resource_specification_query()
      conn = user_conn(user)
      assert fetched = grumble_post_key(q, conn, :resource_specification, %{id: spec.id})
      assert_resource_specification(fetched)
    end

    @tag :skip
    test "fetches a nested resource specification by ID (via Absinthe.run)" do
      user = fake_agent!()
      spec = fake_resource_specification!(user)

      assert queried =
               Bonfire.API.GraphQL.QueryHelper.run_query_id(
                 spec.id,
                 @schema,
                 :resource_specification,
                 4,
                 nil,
                 @debug
               )

      assert_resource_specification(queried)
    end

    test "fails if has been deleted" do
      user = fake_agent!()
      spec = fake_resource_specification!(user)

      q = resource_specification_query()
      conn = user_conn(user)
      assert {:ok, spec} = ResourceSpecifications.soft_delete(spec)

      assert [%{"code" => "not_found", "path" => ["resourceSpecification"], "status" => 404}] =
               grumble_post_errors(q, conn, %{id: spec.id})
    end
  end

  describe "resourceSpecifications" do
    test "returns a list of resourceSpecifications" do
      # users = some_fake_agents!(3)
      # # 9
      # resource_specs = some_fake_resource_specifications!(3, users)

      # root_page_test(%{
      #   query: resource_specifications_query(),
      #   connection: json_conn(),
      #   return_key: :resource_specifications,
      #   default_limit: 5,
      #   total_count: 9,
      #   data: order_follower_count(resource_specifications),
      #   assert_fn: &assert_collection/2,
      #   cursor_fn: Collections.test_cursor(:followers),
      #   after: :collections_after,
      #   before: :collections_before,
      #   limit: :collections_limit
      # })
    end
  end

  describe "createResourceSpecification" do
    test "create a new resource specification" do
      user = fake_agent!()
      q = create_resource_specification_mutation()
      conn = user_conn(user)
      vars = %{resource_specification: resource_specification_input()}

      assert spec =
               grumble_post_key(q, conn, :create_resource_specification, vars)[
                 "resourceSpecification"
               ]

      assert_resource_specification(spec)
    end

    test "creates a new resource specification with a url image" do
      user = fake_agent!()

      q = create_resource_specification_mutation(fields: [:image])
      conn = user_conn(user)

      vars = %{
        resource_specification:
          resource_specification_input(%{
            "image" => "https://via.placeholder.com/150.png"
          })
      }

      assert spec =
               grumble_post_key(q, conn, :create_resource_specification, vars)[
                 "resourceSpecification"
               ]

      assert_resource_specification(spec)

      assert spec["image"] |> String.split_at(-4) |> elem(1) == ".png"
    end

    # test "create a new resource specification with a scope" do
    #   user = fake_agent!()
    #   parent = fake_agent!()

    #   q = create_resource_specification_mutation()
    #   conn = user_conn(user)
    #   vars = %{resource_specification: resource_specification_input(%{"inScopeOf" => parent.id})}
    #   assert spec = grumble_post_key(q, conn, :create_resource_specification, vars)["resourceSpecification"]
    #   assert_resource_specification(spec)
    # end
  end

  describe "updateResourceSpecification" do
    test "update an existing resource specification" do
      user = fake_agent!()
      spec = fake_resource_specification!(user)

      q = update_resource_specification_mutation()
      conn = user_conn(user)
      vars = %{resource_specification: resource_specification_input(%{"id" => spec.id})}

      assert spec =
               grumble_post_key(q, conn, :update_resource_specification, vars)[
                 "resourceSpecification"
               ]

      assert_resource_specification(spec)
    end

    test "fail if has been deleted" do
      user = fake_agent!()
      spec = fake_resource_specification!(user)

      q = update_resource_specification_mutation()
      conn = user_conn(user)
      vars = %{resource_specification: resource_specification_input(%{"id" => spec.id})}
      assert {:ok, _spec} = ResourceSpecifications.soft_delete(spec)

      assert [
               %{
                 "code" => "not_found",
                 "path" => ["updateResourceSpecification"],
                 "status" => 404
               }
             ] = grumble_post_errors(q, conn, vars)
    end
  end

  describe "deleteResourceSpecification" do
    test "deletes an existing resource specification" do
      user = fake_agent!()
      spec = fake_resource_specification!(user)

      q = delete_resource_specification_mutation()
      conn = user_conn(user)
      assert grumble_post_key(q, conn, :delete_resource_specification, %{"id" => spec.id})
    end
  end
end
