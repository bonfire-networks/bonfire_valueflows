defmodule ValueFlows.Planning.Intent.LiveHandler do
  use Bonfire.Web, :live_handler

  alias ValueFlows.Planning.Intent
  alias ValueFlows.Planning.Intent.Intents

  def changeset(attrs \\ %{}) do
    Intent.validate_changeset(attrs)
  end

  def handle_event("create", attrs, socket) do
    with obj_attrs <- attrs
                      |> IO.inspect()
                      |> Map.merge(attrs["intent"])
                      |> input_to_atoms()
                      # |> Map.get(:intent)
                      |> Intents.prepare_attrs()
                      |> IO.inspect(),
    %{valid?: true} = cs <- changeset(obj_attrs),
    {:ok, intent} <- Intents.create(socket.assigns.current_user, obj_attrs) do
      IO.inspect(intent)
      {:noreply, socket |> push_redirect(to: e(attrs, "redirect_after", "/intent/")<>intent.id)}
    end
  end

  def handle_event("status:finished", %{"id" => id} = attrs, socket) do

    with {:ok, intent} <- Intents.one(id: id),
         {:ok, intent} <- Intents.update(intent, %{finished: true}) do
      # IO.inspect(intent)

      redir = if e(attrs, "redirect_after", nil) do
          e(attrs, "redirect_after", "/intent/")<>intent.id
         else
          e(socket.assigns, :current_url, "#")
         end

      {:noreply, socket |> push_redirect(to: redir) }
    end
  end

  def handle_event("assign:select", %{"id" => assign_to, "name"=> name} = attrs, %{assigns: %{current_user: %{id: current_user_id}, intent: %{id: intent_id} = assigned_intent}} = socket) when is_binary(assign_to) do
    # IO.inspect(socket)

    assign_to_id = if assign_to=="me", do: current_user_id, else: assign_to

    with {:ok, intent} <- Intents.one(id: intent_id),
         {:ok, intent} <- Intents.update(intent, %{provider: assign_to_id}) do
      # IO.inspect(intent)
      {:noreply, socket |> push_redirect(to: path(socket.view, intent.id))}
    end
  end


end
