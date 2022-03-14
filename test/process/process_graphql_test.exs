defmodule ValueFlows.Process.GraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true


  import Bonfire.Common.Simulation

  # alias Grumble.PP
  # import Grumble
  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.Process.Processes

  @debug false
  @schema Bonfire.API.GraphQL.Schema

  describe "Process" do
    test "fetches a basic process by ID (via HTTP)" do
      user = fake_agent!()
      process = fake_process!(user)
      q = process_query()
      conn = user_conn(user)
      assert_process(grumble_post_key(q, conn, :process, %{id: process.id}))
    end

    @tag :skip
    test "fetches a full nested process by ID (via Absinthe.run)" do
      user = fake_agent!()

      process = fake_process!(user)

      assert queried =
               Bonfire.API.GraphQL.QueryHelper.run_query_id(
                 process.id,
                 @schema,
                 :process,
                 3,
                 nil,
                 @debug
               )

      assert_process(queried)
    end

    test "fails if has been deleted" do
      user = fake_agent!()
      spec = fake_process!(user)

      q = process_query()
      conn = user_conn(user)

      assert {:ok, spec} = Processes.soft_delete(spec)

      assert [%{"code" => "not_found", "path" => ["process"], "status" => 404}] =
               grumble_post_errors(q, conn, %{id: spec.id})
    end
  end

  describe "Processes" do
    test "returns a list of Processes" do
      user = fake_agent!()
      processes = some(5, fn -> fake_process!(user) end)
      # deleted
      some(2, fn ->
        process = fake_process!(user)
        {:ok, process} = Processes.soft_delete(process)
        process
      end)

      q = processes_query()
      conn = user_conn(user)
      assert fetched_processes = grumble_post_key(q, conn, :processes, %{})
      assert Enum.count(processes) == Enum.count(fetched_processes)
    end
  end

  describe "processesPages" do
    test "fetches all items that are not deleted" do
      user = fake_agent!()
      processes = some(5, fn -> fake_process!(user) end)
      after_process = List.first(processes)
      # create & delete some others
      some(2, fn ->
        process = fake_process!(user)
        {:ok, process} = Processes.soft_delete(process)
        process
      end)
      vars = %{after: after_process.id, limit: 2}
      q = processes_pages_query()
      conn = user_conn(user)
      assert page = grumble_post_key(q, conn, :processes_pages, vars)
      assert 5 == page["totalCount"]
      assert List.first(page["edges"])["id"] == after_process.id
    end
  end


  describe "createProcess" do
    test "create a new process" do
      user = fake_agent!()
      q = create_process_mutation()
      conn = user_conn(user)
      vars = %{process: process_input()}
      assert spec = grumble_post_key(q, conn, :create_process, vars)["process"]
      assert_process(spec)
    end

    test "create a new process with a scope" do
      user = fake_agent!()
      parent = fake_agent!()

      q = create_process_mutation()
      conn = user_conn(user)
      vars = %{process: process_input(%{"inScopeOf" => parent.id})}
      assert spec = grumble_post_key(q, conn, :create_process, vars)["process"]
      assert_process(spec)
    end
  end

  describe "updateProcess" do
    test "update an existing process" do
      user = fake_agent!()
      spec = fake_process!(user)

      q = update_process_mutation()
      conn = user_conn(user)
      vars = %{process: process_input(%{"id" => spec.id})}
      assert spec = grumble_post_key(q, conn, :update_process, vars)["process"]
      assert_process(spec)
    end

    test "fail if has been deleted" do
      user = fake_agent!()
      spec = fake_process!(user)

      q = update_process_mutation()
      conn = user_conn(user)
      vars = %{process: process_input(%{"id" => spec.id})}
      assert {:ok, _spec} = Processes.soft_delete(spec)

      assert [%{"code" => "not_found", "path" => ["updateProcess"], "status" => 404}] =
               grumble_post_errors(q, conn, vars)
    end
  end

  describe "deleteProcess" do
    test "deletes an existing process" do
      user = fake_agent!()
      spec = fake_process!(user)

      q = delete_process_mutation()
      conn = user_conn(user)
      assert grumble_post_key(q, conn, :delete_process, %{id: spec.id})
    end
  end
end
