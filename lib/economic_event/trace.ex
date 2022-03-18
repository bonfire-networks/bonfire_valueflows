defmodule ValueFlows.EconomicEvent.Trace do
  use Bonfire.Common.Utils
  import Where

  alias ValueFlows.Util

  alias ValueFlows.EconomicEvent
  alias ValueFlows.EconomicResource
  alias ValueFlows.Process

  alias ValueFlows.EconomicEvent.EconomicEvents
  alias ValueFlows.EconomicResource.EconomicResources
  alias ValueFlows.Process.Processes

  @max_recurse_limit Util.max_recurse_limit()

  def trace(obj, recurse_limit \\ Util.default_recurse_limit(), recurse_counter \\ 0)

  def trace(objects, recurse_limit, recurse_counter) when is_list(objects) do
    Enum.map(objects, &trace(&1, recurse_limit, recurse_counter))
  end

  def trace(%EconomicResource{} = obj, recurse_limit, recurse_counter) do
    resource(obj, recurse_limit, recurse_counter)
  end

  def trace(%Process{} = obj, recurse_limit, recurse_counter) do
    process(obj, recurse_limit, recurse_counter)
  end

  def trace(%EconomicEvent{} = obj, recurse_limit, recurse_counter) do
    event(obj, recurse_limit, recurse_counter)
  end

  def trace(id, recurse_limit, recurse_counter) when is_binary(id) do
    with {:ok, obj} <- Bonfire.Common.Pointers.get(id, skip_boundary_check: true) do
      trace(obj, recurse_limit, recurse_counter)
    end
  end


  defp maybe_recurse(objects, recurse_limit \\ Util.default_recurse_limit(), recurse_counter \\ 0)

  defp maybe_recurse(objects, recurse_limit, recurse_counter) when is_nil(recurse_limit) or recurse_limit > @max_recurse_limit, do: maybe_recurse(objects, Util.default_recurse_limit(), recurse_counter)

  defp maybe_recurse(objects, recurse_limit, recurse_counter) when is_nil(recurse_limit) or (recurse_counter + 1) < recurse_limit do
    if (recurse_counter + 1) < recurse_limit || Util.default_recurse_limit() do
      debug("Trace: recurse level #{recurse_counter} of #{recurse_limit}")
      recurse(objects, recurse_limit, recurse_counter+1)
      # |> IO.inspect(label: "Trace recursed")
    else
      objects
    end
  end

  defp maybe_recurse(obj, _, _), do: obj


  defp recurse(objects, recurse_limit, recurse_counter) when is_list(objects) and length(objects)>0 do
    Enum.map(
      objects,
      &maybe_recurse(&1, recurse_limit, recurse_counter)
    )
    |> List.flatten()
    |> Enum.uniq()
  end

  defp recurse(%{} = obj, recurse_limit, recurse_counter) do
    with {:ok, nested} <- trace(obj, recurse_limit, recurse_counter) do
      obj
      |> maybe_append(
          nested
        )
    end
  end

  defp recurse(obj, _, _), do: obj


  def resource(resource_or_id, recurse_limit \\ Util.default_recurse_limit(), recurse_counter \\ 0)

  def resource(resource_or_id, recurse_limit, recurse_counter) do
    with {:ok, events} <- EconomicEvents.many([:default, trace_resource: ulid(resource_or_id)]) do
      {:ok, events
        |> maybe_recurse(recurse_limit, recurse_counter)
      }
      # |> IO.inspect(label: "resource_trace")
    end
  end


  def process(process, recurse_limit \\ Util.default_recurse_limit(), recurse_counter \\ 0)

  def process(process, recurse_limit, recurse_counter)  do
    with {:ok, events} <- EconomicEvents.inputs_of(process) do
      {:ok, events
        |> maybe_recurse(recurse_limit, recurse_counter)
      }
    end
  end


  def event(event, recurse_limit \\ Util.default_recurse_limit(), recurse_counter \\ 0)

  def event(event, recurse_limit, recurse_counter) do
    with {:ok, resources} <- trace_resource_input(event),
         {:ok, resource_inventoried_as} <- trace_resource_inventoried_as(event),
         {:ok, process} <- trace_process_output(event)
          do
      {
        :ok,
        (
          resources
          |> maybe_append(resource_inventoried_as)
          |> maybe_append(process)
        )
        |> maybe_recurse(recurse_limit, recurse_counter)
      }
    end
  end

  defp trace_resource_input(%{input_of_id: input_of_id}) when not is_nil(input_of_id) do
    EconomicResources.inputs_of(input_of_id)
  end

  defp trace_resource_input(_) do
    {:ok, []}
  end

  defp trace_resource_inventoried_as(
         %{action_id: action_id, resource_inventoried_as_id: resource_inventoried_as_id} = _event
       )
       when action_id in ["transfer", "move"] and not is_nil(resource_inventoried_as_id) do
    EconomicResources.one([:default, id: resource_inventoried_as_id])
  end

  defp trace_resource_inventoried_as(_) do
    {:ok, nil}
  end

  defp trace_process_output(%{output_of_id: output_of_id}) when not is_nil(output_of_id) do
    Processes.one([:default, id: output_of_id])
  end

  defp trace_process_output(_) do
    {:ok, nil}
  end

end
