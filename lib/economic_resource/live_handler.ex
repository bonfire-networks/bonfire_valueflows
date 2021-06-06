defmodule ValueFlows.EconomicResource.LiveHandler do
  use Bonfire.Web, :live_handler

  alias ValueFlows.EconomicResource
  alias ValueFlows.EconomicResource.EconomicResources


  def handle_event("autocomplete", search, socket) when is_binary(search) do

    matches = with {:ok, matches} <- EconomicResources.many(autocomplete: search) do
      # IO.inspect(matches)
      matches |> Enum.map(&to_tuple/1)
    else
      _ -> []
    end
    IO.inspect(matches)


    {:noreply, socket |> assign_global(resources_inventoried_as_autocomplete: matches) }
  end


  def handle_event("select", %{"id" => select_resource, "name"=> name} = attrs, socket) when is_binary(select_resource) do
    # IO.inspect(socket)

    selected = {name, select_resource}

    IO.inspect(selected)
    {:noreply, socket |> assign_global(resource_inventoried_as_selected: [selected])}
  end

  def to_tuple(resource_spec) do
    {resource_spec.name, resource_spec.id}
  end

end
