defmodule ValueFlows.Web.My.PublishAdLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)
    }
  end

  def handle_event("toggle_ad", _data, socket) do
    {:noreply, assign(socket, :toggle_ad, !socket.assigns.toggle_ad)}
  end

  def handle_event("publish_ad", data, socket) do
    publish_ad(data, socket)
  end

  # need to alias some form posting events here to workaround having two events but one target on a form
  def handle_event("tag_suggest", data, socket) do
    CommonsPub.Web.Component.TagAutocomplete.tag_suggest(data, socket)
  end

  def publish_ad(data, socket) do
    intent = input_to_atoms(data)
    # IO.inspect(intent, label: "intent to create")

    {:ok, _new_intent} =
      ValueFlows.Planning.Intent.GraphQL.create_intent(%{intent: intent}, %{
        context: %{current_user: socket.assigns.current_user}
      })

    # IO.inspect(new_intent)

    {:noreply,
     socket
     |> put_flash(:info, "intent created !")}
  end
end
