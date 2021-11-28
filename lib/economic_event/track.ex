defmodule ValueFlows.EconomicEvent.Track do
  import Bonfire.Common.Utils
  require Logger

  alias ValueFlows.Util

  alias ValueFlows.EconomicEvent
  alias ValueFlows.EconomicResource
  alias ValueFlows.Process

  alias ValueFlows.EconomicEvent.EconomicEvents
  alias ValueFlows.EconomicResource.EconomicResources
  alias ValueFlows.Process.Processes


  def track(obj, recurse_limit \\ Util.default_recurse_limit(), recurse_counter \\ 0)

  def track(objects, recurse_limit, recurse_counter) when is_list(objects) do
    Enum.map(objects, &track(&1, recurse_limit, recurse_counter))
  end

  def track(%EconomicResource{} = obj, recurse_limit, recurse_counter) do
    resource(obj, recurse_limit, recurse_counter)
  end

  def track(%Process{} = obj, recurse_limit, recurse_counter) do
    process(obj, recurse_limit, recurse_counter)
  end

  def track(%EconomicEvent{} = obj, recurse_limit, recurse_counter) do
    event(obj, recurse_limit, recurse_counter)
  end

  def track(id, recurse_limit, recurse_counter) when is_binary(id) do
    with {:ok, obj} <- Bonfire.Common.Pointers.get(id, skip_boundary_check: true) do
      track(obj, recurse_limit, recurse_counter)
    end
  end


  defp maybe_recurse(objects, recurse_limit \\ Util.default_recurse_limit(), recurse_counter \\ 0)

  defp maybe_recurse(objects, recurse_limit, recurse_counter) when is_nil(recurse_limit) or (recurse_counter + 1) < recurse_limit do
    if (recurse_counter + 1) < recurse_limit || Util.default_recurse_limit() do
      Logger.info("Track: recurse level #{recurse_counter} of #{recurse_limit}")
      recurse(objects, recurse_limit, recurse_counter+1)
      # |> IO.inspect(label: "Track recursed")
    else
      objects
    end
  end

  defp maybe_recurse(obj, _, _), do: obj


  defp recurse(objects, recurse_limit, recurse_counter) when is_list(objects) and length(objects)>0 do
    Enum.map(
      objects,
      &recurse(&1, recurse_limit, recurse_counter)
    )
    |> List.flatten()
    |> Enum.uniq()
  end

  defp recurse(%{} = obj, recurse_limit, recurse_counter) do
    with {:ok, nested} <- track(obj, recurse_limit, recurse_counter) do
      obj
      |> maybe_append(
          nested
        )
    end
  end

  defp recurse(obj, _, _), do: obj


  def resource(id, recurse_limit \\ Util.default_recurse_limit(), recurse_counter \\ 0)

  def resource(resource_or_id, recurse_limit, recurse_counter) do
    with {:ok, events} <- EconomicEvents.many([:default, track_resource: maybe_get_id(resource_or_id)]) do
      {:ok, events
        |> maybe_recurse(recurse_limit, recurse_counter)
      }
      # |> IO.inspect(label: "resource_track")
    end
  end


  def process(process, recurse_limit \\ Util.default_recurse_limit(), recurse_counter \\ 0)

  def process(process, recurse_limit, recurse_counter) do
    with {:ok, events} <- EconomicEvents.outputs_of(process) do
      {:ok, events
        |> maybe_recurse(recurse_limit, recurse_counter)
      }
    end
  end


  def event(event, recurse_limit \\ Util.default_recurse_limit(), recurse_counter \\ 0)

  def event(event, recurse_limit, recurse_counter) do
  # processes is actually only one, so we can use [process | resources]
    with {:ok, resources} <- track_resource_output(event),
         {:ok, to_resource} <- track_to_resource_output(event),
         {:ok, process} <- track_process_input(event) do
      {
        :ok,
        (
          resources
          |> maybe_append(process)
          |> maybe_append(to_resource)
        )
        |> maybe_recurse(recurse_limit, recurse_counter)
      }
    end
  end


  defp track_to_resource_output(
         %{action_id: action_id, to_resource_inventoried_as_id: to_resource_inventoried_as_id} =
           _event
       )
       when action_id in ["transfer", "move"] and not is_nil(to_resource_inventoried_as_id) do
    EconomicResources.one([:default, id: to_resource_inventoried_as_id])
  end

  defp track_to_resource_output(_) do
    {:ok, nil}
  end

  defp track_resource_output(%{output_of_id: output_of_id}) when not is_nil(output_of_id) do
    EconomicResources.outputs_of(output_of_id)
  end

  defp track_resource_output(_) do
    {:ok, []}
  end

  defp track_process_input(%{input_of_id: input_of_id}) when not is_nil(input_of_id) do
    Processes.one([:default, id: input_of_id])
  end

  defp track_process_input(_) do
    {:ok, nil}
  end
end
