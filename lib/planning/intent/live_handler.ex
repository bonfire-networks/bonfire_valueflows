defmodule ValueFlows.Planning.Intent.LiveHandler do
  import Phoenix.LiveView
  import Bonfire.Common.Utils
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
    {ok, intent} <- Intents.create(socket.assigns.current_user, obj_attrs) do
      IO.inspect(intent)
      {:noreply, socket |> push_redirect(to: e(attrs, "redirect_after", "/intent/")<>intent.id)}
    end
  end

  def handle_event("status_finished", %{"id" => id} = attrs, socket) do

    with {ok, intent} <- Intents.one(id: id),
         {ok, intent} <- Intents.update(intent, %{finished: true}) do
      IO.inspect(intent)
      {:noreply, socket |> push_redirect(to: e(attrs, "redirect_after", "/intent/")<>intent.id)}
    end
  end

end
