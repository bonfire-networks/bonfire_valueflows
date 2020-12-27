defmodule ValueFlows.Observation.Process.GraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true


  import Bonfire.Common.Simulation

  # alias Grumble.PP
  # import Grumble
  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.Observation.Process.Processes

  @debug false
  @schema Bonfire.GraphQL.Schema

  describe "Process" do
    test "fetches a basic process by ID (via HTTP)" do
      user = fake_agent!()
      process = fake_process!(user)
      q = process_query()
      conn = user_conn(user)
      assert_process(grumble_post_key(q, conn, :process, %{id: process.id}))
    end

    test "fetches a full nested process by ID (via Absinthe.run)" do
      user = fake_agent!()

      process = fake_process!(user)

      assert queried =
               Bonfire.GraphQL.QueryHelper.run_query_id(
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
      # deleted
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

  describe "Process.track" do
    test "Returns a list of economic events that are outputs" do
      user = fake_agent!()
      process = fake_process!(user)

      _output_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            action: "produce"
          })
        end)

      q = process_query(fields: [track: [:id]])
      conn = user_conn(user)

      assert process = grumble_post_key(q, conn, :process, %{id: process.id})
      assert Enum.count(process["track"]) == 5
    end
  end

  describe "Process.trace" do
    test "Returns a list of economic events that are outputs" do
      user = fake_agent!()
      process = fake_process!(user)

      _input_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            input_of: process.id,
            action: "consume"
          })
        end)

      q = process_query(fields: [trace: [:id]])
      conn = user_conn(user)

      assert process = grumble_post_key(q, conn, :process, %{id: process.id})
      assert Enum.count(process["trace"]) == 5
    end
  end

  describe "Process.inputs" do
    test "Returns a list of economic events that are inputs" do
      user = fake_agent!()
      process = fake_process!(user)

      _input_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            input_of: process.id,
            action: "use"
          })
        end)

      q = process_inputs_query(fields: economic_event_fields())
      conn = user_conn(user)

      assert process = grumble_post_key(q, conn, :process, %{id: process.id})
      assert Enum.count(process["inputs"]) == 5
    end

    test "Returns a list of economic events that are inputs and with an action consume" do
      user = fake_agent!()
      process = fake_process!(user)

      _input_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            input_of: process.id,
            action: "consume"
          })
        end)

      _other_input_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            input_of: process.id,
            action: "use"
          })
        end)

      q = process_inputs_query(fields: economic_event_fields())
      conn = user_conn(user)

      assert process =
               grumble_post_key(q, conn, :process, %{id: process.id, action_id: "consume"})

      assert Enum.count(process["inputs"]) == 5
    end
  end

  describe "Process.outputs" do
    test "Returns a list of economic events that are outputs" do
      user = fake_agent!()
      process = fake_process!(user)

      _output_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            action: "produce"
          })
        end)

      q = process_outputs_query(fields: economic_event_fields())
      conn = user_conn(user)

      assert process = grumble_post_key(q, conn, :process, %{id: process.id})
      assert Enum.count(process["outputs"]) == 5
    end

    test "Returns a list of economic events that are outputs and with an action consume" do
      user = fake_agent!()
      process = fake_process!(user)

      _output_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            action: "produce"
          })
        end)

      _other_output_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            action: "raise"
          })
        end)

      q = process_outputs_query(fields: economic_event_fields())
      conn = user_conn(user)

      assert process =
               grumble_post_key(q, conn, :process, %{id: process.id, action_id: "produce"})

      assert Enum.count(process["outputs"]) == 5
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
