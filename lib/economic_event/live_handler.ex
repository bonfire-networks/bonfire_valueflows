defmodule ValueFlows.EconomicEvent.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  use Arrows

  alias ValueFlows.EconomicEvent
  alias ValueFlows.EconomicEvent.EconomicEvents

  def changeset(attrs \\ %{}) do
    EconomicEvent.validate_changeset(attrs)
  end

  def handle_event("create", attrs, socket) do
    creator = current_user(socket) #|> debug("creator")
    # debug(socket: socket)

    with obj_attrs <- attrs
                      # |> debug()
                      |> Map.merge(attrs["economic_event"])
                      |> Map.drop(["economic_event"])
                      |> input_to_atoms()
                      # |> Map.get(:event)
                      |> prepare_attrs(creator)
                      |> debug("create_event_attrs"),
    %{valid?: true} = cs <- changeset(obj_attrs),
    {:ok, event} <- EconomicEvents.create(creator, obj_attrs) do
      # debug(created: event)

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

  def prepare_attrs(attrs, creator) do
    attrs
    |> EconomicEvents.prepare_create_attrs(creator)
    |> maybe_put(:has_point_in_time, maybe_date(e(attrs, :has_point_in_time, nil)))
    |> maybe_put(:has_beginning, maybe_date(e(attrs, :has_beginning, nil)))
    |> maybe_put(:has_end, maybe_date(e(attrs, :has_end, nil)))
  end

  def maybe_date(d) when is_binary(d) and d !="" do
    Date.from_iso8601(d)
    ~> NaiveDateTime.new(~T[00:00:00])
    ~> Ecto.Type.cast(:utc_datetime_usec, ...)
    |> debug
    |> ok_or()
  end
  def maybe_date(_d) do
    nil
  end
end
