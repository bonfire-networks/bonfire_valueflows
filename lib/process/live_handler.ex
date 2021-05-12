defmodule ValueFlows.Process.LiveHandler do
  use Bonfire.Web, :live_handler

  alias ValueFlows.Process
  alias ValueFlows.Process.Processes

  def changeset(attrs \\ %{}) do
    Process.validate_changeset(attrs)
  end

  def handle_event("create", attrs, socket) do
    with obj_attrs <- attrs
                      # |> IO.inspect()
                      |> input_to_atoms()
                      |> Map.get(:process)
                      |> Processes.prepare_attrs(),
    %{valid?: true} = cs <- changeset(obj_attrs),
    {:ok, process} <- Processes.create(socket.assigns.current_user, obj_attrs) do
      IO.inspect(process)
      {:noreply, socket |> push_redirect(to: e(attrs, "redirect_after", "/process/")<>process.id)}
    end
  end

end
