defmodule ValueFlows.EconomicEvent.LiveHandler do
  use Bonfire.Web, :live_handler

  alias ValueFlows.EconomicEvent
  alias ValueFlows.EconomicEvent.EconomicEvents

  def changeset(attrs \\ %{}) do
    EconomicEvent.validate_changeset(attrs)
  end

  def handle_event("create", attrs, socket) do
    creator = current_user(socket) #|> IO.inspect(label: "creator")
    # IO.inspect(socket: socket)

    with obj_attrs <- attrs
                      |> IO.inspect()
                      |> Map.merge(attrs["economic_event"])
                      |> Map.drop(["economic_event"])
                      |> input_to_atoms()
                      # |> Map.get(:event)
                      |> EconomicEvents.prepare_create_attrs(creator)
                      |> IO.inspect(label: "create_event_attrs"),
    %{valid?: true} = cs <- changeset(obj_attrs),
    {:ok, event} <- EconomicEvents.create(creator, obj_attrs) do
      # IO.inspect(created: event)

      if e(event, :economic_resource, :id, nil) do
        {:noreply, socket |> push_redirect(to: e(attrs, "redirect_after", "/resource/")<>e(event, :economic_resource, :id, ""))}
      else
        {:noreply, socket |> push_redirect(to: path(e(event, :economic_event, nil)))}
        # {:noreply, socket |> put_flash(:success, "Event recorded!")}
      end
    # else
    #   {:error, error} ->
    #     {:noreply, assign(socket, form_error: error_msg(error))}

    #   %Ecto.Changeset{} = cs ->
    #     {:noreply, assign(socket, changeset: cs, form_error: error_msg(cs))} #|> IO.inspect
    end
  end


end
