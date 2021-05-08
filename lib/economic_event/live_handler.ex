defmodule ValueFlows.EconomicEvent.LiveHandler do
  use Bonfire.Web, :live_handler

  alias ValueFlows.EconomicEvent
  alias ValueFlows.EconomicEvent.EconomicEvents

  def changeset(attrs \\ %{}) do
    EconomicEvent.validate_changeset(attrs)
  end

  def handle_event("create", attrs, socket) do
    with obj_attrs <- attrs
                      |> IO.inspect()
                      |> Map.merge(attrs["economic_event"])
                      |> Map.drop(["economic_event"])
                      |> input_to_atoms()
                      # |> Map.get(:event)
                      |> EconomicEvents.prepare_attrs()
                      |> IO.inspect(label: "obj_attrs"),
    %{valid?: true} = cs <- changeset(obj_attrs),
    {ok, event} <- EconomicEvents.create(socket.assigns.current_user, obj_attrs) do
      IO.inspect(event)
      {:noreply, socket
        # |> push_redirect(to: e(attrs, "redirect_after", "/event/")<>e(event, :economic_event, :id, ""))
        |> push_redirect(to: e(attrs, "redirect_after", "/resource/")<>e(event, :economic_resource, :id, e(event, :economic_event, :id, "")))
      }
    end
  end



end
