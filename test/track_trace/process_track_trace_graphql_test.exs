defmodule ValueFlows.Process.TrackTraceGraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true


  import Bonfire.Common.Simulation

  # alias Grumble.PP
  # import Grumble
  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.Process.Processes

  @debug false
  @schema Bonfire.API.GraphQL.Schema


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

      q = process_query(fields: [track: [:__typename]])
      conn = user_conn(user)

      assert process = grumble_post_key(q, conn, :process, %{id: process.id})
      assert Enum.count(process["track"]) >= 5
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

      q = process_query(fields: [trace: [:__typename]])
      conn = user_conn(user)

      assert process = grumble_post_key(q, conn, :process, %{id: process.id})
      assert Enum.count(process["trace"]) >= 5
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

end
