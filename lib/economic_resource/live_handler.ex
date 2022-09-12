defmodule ValueFlows.EconomicResource.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler

  alias ValueFlows.EconomicResource
  alias ValueFlows.EconomicResource.EconomicResources

  def handle_event("autocomplete", %{"value" => search}, socket),
    do: handle_event("autocomplete", search, socket)

  def handle_event("autocomplete", search, socket) when is_binary(search) do
    options =
      (EconomicResources.search(search) || [])
      |> Enum.map(&to_tuple/1)

    # debug(matches)

    {:noreply, assign_global(socket, economic_resources_autocomplete: options)}
  end

  def handle_event(
        "select",
        %{"id" => select_resource, "name" => name} = attrs,
        socket
      )
      when is_binary(select_resource) do
    # debug(socket)

    selected = {name, select_resource}

    debug(selected)
    {:noreply, assign_global(socket, economic_resource_selected: [selected])}
  end

  def to_tuple(resource_spec) do
    {resource_spec.name, resource_spec.id}
  end
end
