defmodule ValueFlows.Process.ProcessesTrackTraceTest do
  use Bonfire.ValueFlows.DataCase, async: true

  import Bonfire.Common.Simulation

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.Process.Processes

  describe "track" do
    test "Returns EconomicEvents that are outputs" do
      user = fake_agent!()
      process = fake_process!(user)

      _input_events =
        some(3, fn ->
          fake_economic_event!(user, %{
            input_of: process.id,
            action: "consume"
          })
        end)

      output_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            action: "produce"
          })
        end)

      assert {:ok, events} = Processes.track(process)

      ids = Enum.map(events, & &1.id)

      for %{id: id} <- output_events do
        assert id in ids
      end
    end
  end

  describe "trace" do
    test "Return EconomicEvents that are inputs" do
      user = fake_agent!()
      process = fake_process!(user)

      input_events =
        some(3, fn ->
          fake_economic_event!(user, %{
            input_of: process.id,
            action: "consume"
          })
        end)

      _output_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            action: "produce"
          })
        end)

      assert {:ok, events} = Processes.trace(process)
      assert Enum.map(events, & &1.id) == Enum.map(input_events, & &1.id)
    end
  end

  describe "inputs" do
    test "return EconomicEvents that are inputs" do
      user = fake_agent!()
      process = fake_process!(user)

      input_events =
        some(3, fn ->
          fake_economic_event!(user, %{
            input_of: process.id,
            action: "consume"
          })
        end)

      _output_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            action: "produce"
          })
        end)

      assert {:ok, events} = Processes.inputs(process)
      assert Enum.map(events, & &1.id) == Enum.map(input_events, & &1.id)
    end

    test "return EconomicEvents that are inputs and with action consume" do
      user = fake_agent!()
      process = fake_process!(user)

      input_events =
        some(3, fn ->
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

      assert {:ok, events} = Processes.inputs(process, "consume")
      assert Enum.map(events, & &1.id) == Enum.map(input_events, & &1.id)
    end
  end

  describe "outputs" do
    test "return EconomicEvents that are ouputs" do
      user = fake_agent!()
      process = fake_process!(user)

      _input_events =
        some(3, fn ->
          fake_economic_event!(user, %{
            input_of: process.id,
            action: "consume"
          })
        end)

      output_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            action: "produce"
          })
        end)

      assert {:ok, events} = Processes.outputs(process)
      assert Enum.map(events, & &1.id) == Enum.map(output_events, & &1.id)
    end

    test "return EconomicEvents that are ouputs and with action produce" do
      user = fake_agent!()
      process = fake_process!(user)

      _other_output_events =
        some(3, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            action: "raise"
          })
        end)

      output_events =
        some(5, fn ->
          fake_economic_event!(user, %{
            output_of: process.id,
            action: "produce"
          })
        end)

      assert {:ok, events} = Processes.outputs(process, "produce")

      assert events |> Enum.map(& &1.id) |> Enum.sort() ==
               output_events |> Enum.map(& &1.id) |> Enum.sort()
    end
  end
end
