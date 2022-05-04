defmodule ValueFlows.Process.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler

  alias ValueFlows.Process
  alias ValueFlows.Process.Processes

  def changeset(attrs \\ %{}) do
    Process.validate_changeset(attrs)
  end

  def handle_event("create", attrs, socket) do
    with obj_attrs <- attrs
                      # |> debug()
                      |> input_to_atoms()
                      |> Map.get(:process)
                      |> Processes.prepare_attrs(),
    %{valid?: true} = cs <- changeset(obj_attrs),
    {:ok, process} <- Processes.create(current_user(socket), obj_attrs) do
      debug(process)
      {:noreply, socket |> push_redirect(to: e(attrs, "redirect_after", "/process/")<>process.id)}
    end
  end

  def handle_event("update", attrs, %{assigns: %{process: %{id: process_id}}} = socket) do
    debug(process: attrs)
    do_update(process_id, attrs |> Map.get("process") |> input_to_atoms(), socket)
  end

  def handle_event("status:finished", %{"id" => id} = attrs, socket) do
    # TODO: record by who
    do_update(id, %{finished: true}, socket)
  end

  def handle_event("status:unfinished", %{"id" => id} = attrs, socket) do
    # TODO: record by who
    do_update(id, %{finished: false}, socket)
  end

  def do_update(id, attrs, socket) do
    # TODO: check permissions
    with {:ok, process} <- Processes.one(id: id),
         {:ok, process} <- Processes.update(process, attrs) do
      # debug(intent)

      redir = if e(attrs, "redirect_after", "") !="" do
          attrs["redirect_after"]<>process.id
         else
          path(process)
         end

      {:noreply, socket |> push_redirect(to: redir) }
    end
  end

end
