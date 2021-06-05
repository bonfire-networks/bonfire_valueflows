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
    {:ok, process} <- Processes.create(e(socket.assigns, :current_user, nil), obj_attrs) do
      IO.inspect(process)
      {:noreply, socket |> push_redirect(to: e(attrs, "redirect_after", "/process/")<>process.id)}
    end
  end

  def handle_event("update", attrs, %{assigns: %{process: %{id: process_id}}} = socket) do
    do_update(process_id, attrs |> Map.get("process") |> input_to_atoms(), socket)
  end

  def handle_event("status:finished", %{"id" => id} = attrs, socket) do
    # TODO: record by who
    do_update(id, %{finished: true}, socket)
  end

  def do_update(id, attrs, %{assigns: %{current_user: current_user}} = socket) do
    IO.inspect(attrs: attrs)
    # TODO: check permissions
    with {:ok, process} <- Processes.one(id: id),
         {:ok, process} <- Processes.update(process, attrs) do
      # IO.inspect(intent)

      redir = if e(attrs, "redirect_after", nil) do
          e(attrs, "redirect_after", "/process/")<>process.id
         else
          e(socket.assigns, :current_url, "#")
         end

      {:noreply, socket |> push_redirect(to: redir) }
    end
  end

end
