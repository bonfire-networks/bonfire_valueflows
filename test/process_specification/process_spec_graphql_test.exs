defmodule ValueFlows.Knowledge.ProcessSpecification.GraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  # import Bonfire.Common.Simulation


  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.Knowledge.ProcessSpecification.ProcessSpecifications

  @debug false
  @schema Bonfire.API.GraphQL.Schema

  describe "processSpecification" do
    test "fetches a process specification by ID (via HTTP)" do
      user = fake_agent!()
      spec = fake_process_specification!(user)

      q = process_specification_query()
      conn = user_conn(user)
      assert fetched = grumble_post_key(q, conn, :process_specification, %{id: spec.id})
      assert_process_specification(fetched)
    end

    test "fetches a nested process specification by ID (via Absinthe.run)" do
      user = fake_agent!()
      spec = fake_process_specification!(user)

      assert queried =
               Bonfire.API.GraphQL.QueryHelper.run_query_id(
                 spec.id,
                 @schema,
                 :process_specification,
                 4,
                 nil,
                 @debug
               )

      assert_process_specification(queried)
    end

    test "fails if has been deleted" do
      user = fake_agent!()
      spec = fake_process_specification!(user)

      q = process_specification_query()
      conn = user_conn(user)
      assert {:ok, spec} = ProcessSpecifications.soft_delete(spec)

      assert [%{"code" => "not_found", "path" => ["processSpecification"], "status" => 404}] =
               grumble_post_errors(q, conn, %{id: spec.id})
    end
  end

  describe "processSpecifications" do
    test "returns a list of processSpecifications" do
      # users = some_fake_agents!(3)
      # # 9
      # process_specs = some_fake_process_specifications!(3, users)

      # root_page_test(%{
      #   query: process_specifications_query(),
      #   connection: json_conn(),
      #   return_key: :process_specifications,
      #   default_limit: 5,
      #   total_count: 9,
      #   data: order_follower_count(process_specifications),
      #   assert_fn: &assert_collection/2,
      #   cursor_fn: Collections.test_cursor(:followers),
      #   after: :collections_after,
      #   before: :collections_before,
      #   limit: :collections_limit
      # })
    end
  end

  describe "createProcessSpecification" do
    test "create a new process specification" do
      user = fake_agent!()
      q = create_process_specification_mutation()
      conn = user_conn(user)
      vars = %{process_specification: process_specification_input()}

      assert spec =
               grumble_post_key(q, conn, :create_process_specification, vars)[
                 "processSpecification"
               ]

      assert_process_specification(spec)
    end

    # test "create a new process specification with a scope" do
    #   user = fake_agent!()
    #   parent = fake_agent!()

    #   q = create_process_specification_mutation()
    #   conn = user_conn(user)
    #   vars = %{process_specification: process_specification_input(%{"inScopeOf" => parent.id})}
    #   assert spec = grumble_post_key(q, conn, :create_process_specification, vars)["processSpecification"]
    #   assert_process_specification(spec)
    # end
  end

  describe "updateProcessSpecification" do
    test "update an existing process specification" do
      user = fake_agent!()
      spec = fake_process_specification!(user)

      q = update_process_specification_mutation()
      conn = user_conn(user)
      vars = %{process_specification: process_specification_input(%{"id" => spec.id})}

      assert spec =
               grumble_post_key(q, conn, :update_process_specification, vars)[
                 "processSpecification"
               ]

      assert_process_specification(spec)
    end

    test "fail if has been deleted" do
      user = fake_agent!()
      spec = fake_process_specification!(user)

      q = update_process_specification_mutation()
      conn = user_conn(user)
      vars = %{process_specification: process_specification_input(%{"id" => spec.id})}
      assert {:ok, _spec} = ProcessSpecifications.soft_delete(spec)

      assert [%{"code" => "not_found", "path" => ["updateProcessSpecification"], "status" => 404}] =
               grumble_post_errors(q, conn, vars)
    end
  end

  describe "deleteProcessSpecification" do
    test "deletes an existing process specification" do
      user = fake_agent!()
      spec = fake_process_specification!(user)

      q = delete_process_specification_mutation()
      conn = user_conn(user)
      assert grumble_post_key(q, conn, :delete_process_specification, %{"id" => spec.id})
    end
  end
end
