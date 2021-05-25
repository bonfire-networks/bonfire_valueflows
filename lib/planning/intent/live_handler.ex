defmodule ValueFlows.Planning.Intent.LiveHandler do
  use Bonfire.Web, :live_handler

  alias ValueFlows.Planning.Intent
  alias ValueFlows.Planning.Intent.Intents

  def changeset(attrs \\ %{}) do
    Intent.validate_changeset(attrs)
  end

  def create_from_list(current_user, obj_attrs, [i_intent | tail], tree_of_parent_ids, previous_indentation \\ "", latest_intent_id \\ nil) do

    indentation = Enum.at(i_intent, 1)
     |> String.replace(~r/\t/, "    ")
    checked = Enum.at(i_intent, 2)

    tree_of_parent_ids = if latest_intent_id && bit_size(indentation) > bit_size(previous_indentation) do
      # nest one level down
      tree_of_parent_ids ++ [latest_intent_id]
    else
      if bit_size(indentation) < bit_size(previous_indentation) do
        # nest one level up (by removing last id in tree)
        tree_of_parent_ids |> Enum.reverse() |> tl() |> Enum.reverse()
      else
        # same as previous item
        tree_of_parent_ids
      end
    end

    {_, subintent} = Intents.create(current_user, Map.merge(obj_attrs,
      %{
        name: Enum.at(i_intent, 3),
        in_scope_of: [List.last(tree_of_parent_ids)],
        note: nil,
        finished: checked=="x" || checked=="X",
      }
    ))

    # iterate
    create_from_list(current_user, obj_attrs, tail, tree_of_parent_ids, indentation, subintent.id)
  end

  def create_from_list(_, _, [], _, _, _, _) do
    nil
  end

  def handle_event("create", attrs, socket) do
    with obj_attrs <- attrs
                      # |> IO.inspect()
                      |> Map.merge(attrs["intent"])
                      |> input_to_atoms()
                      |> Intents.prepare_attrs()
                      |> IO.inspect(),
    %{valid?: true} = cs <- changeset(obj_attrs),
    {:ok, intent} <- Intents.create(socket.assigns.current_user, obj_attrs) do
      IO.inspect(intent)

      case Bonfire.Common.Text.list_checkboxes(intent.note) do
        sub_intents when length(sub_intents) > 0 ->
          IO.inspect(sub_intents)

          create_from_list(socket.assigns.current_user, obj_attrs, sub_intents, [intent.id])

          # for sub_intent <- sub_intents do
          #   Intents.create(socket.assigns.current_user, Map.merge(obj_attrs, %{name: Enum.at(sub_intent, 3), note: nil, in_scope_of: [intent.id] }))
          # end

        _ -> nil
      end

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

  def handle_event("update:"<>what, %{"id" => id} = attrs, socket) do

    with {:ok, intent} <- Intents.one(id: id),
         {:ok, intent} <- Intents.update(intent, attrs) do
      # IO.inspect(intent)

      redir = if e(attrs, "redirect_after", nil) do
          e(attrs, "redirect_after", "/intent/")<>intent.id
         else
          e(socket.assigns, :current_url, "#")
         end

      {:noreply, socket |> push_redirect(to: redir) }
    end
  end

  def handle_event("update:"<>what, attrs, %{assigns: %{intent: %{id: intent_id}}} = socket) when is_binary(intent_id) do
    # IO.inspect(socket)

    handle_event("update:"<>what, Map.merge(%{"id" => intent_id}, attrs), socket)
  end

  def handle_event("assign:select", %{"id" => assign_to, "name"=> name} = attrs, %{assigns: %{current_user: %{id: current_user_id}, intent: %{id: intent_id}}} = socket) when is_binary(assign_to) do
    # IO.inspect(socket)

    assign_to(assign_to, intent_id, path(socket.view, intent_id), current_user_id, socket)
  end

  def handle_event("assign:select", %{"id" => assign_to, "name"=> name, "context_id" => intent_id} = attrs, %{assigns: %{current_user: %{id: current_user_id}, process: %{id: process_id}}} = socket) when is_binary(assign_to) do
    # IO.inspect(socket)

    assign_to(assign_to, intent_id, path(socket.view, process_id), current_user_id, socket)

  end

  def handle_event("assign:select", %{"id" => assign_to, "name"=> name, "context_id" => intent_id} = attrs, %{assigns: %{current_user: %{id: current_user_id}}} = socket) when is_binary(assign_to) do
    # IO.inspect(socket)

    assign_to(assign_to, intent_id, nil, current_user_id, socket)
  end

  def assign_to(assign_to, intent_id, redirect_path, current_user_id, socket) do
    assign_to_id = if assign_to=="me", do: current_user_id, else: assign_to

    with {:ok, intent} <- Intents.one(id: intent_id),
         {:ok, intent} <- Intents.update(intent, %{provider: assign_to_id}) do
      # IO.inspect(intent)
      {:noreply, socket |> push_redirect(to: redirect_path || e(socket.assigns, :current_url, "#"))}
    end
  end

  def handle_param("search", %{"term" => term} = attrs, socket) do
    with {:ok, intents} <- Intents.many([:default, search: term]) do
      {:noreply, socket |> assign_global(socket, %{intents: intents})}
    end
  end

  def handle_param("filter", %{"filter_by" => filters} = attrs, socket) do
    with {:ok, intents} <- Intents.many([:default | filters]) do
      {:noreply, socket |> assign_global(socket, %{intents: intents})}
    end
  end

  def handle_param("sort", %{"sort_by" => sort_key} = attrs, socket) do
    with {:ok, intents} <- Intents.many([:default, order: String.to_existing_atom(sort_key)]) do
      {:noreply, socket |> assign_global(socket, %{intents: intents})}
    end
  end
end
