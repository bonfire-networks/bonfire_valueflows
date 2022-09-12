defmodule ValueFlows.Planning.Intent.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler

  alias ValueFlows.Planning.Intent
  alias ValueFlows.Planning.Intent.Intents

  @default_path "/?no_redirect_set"

  @doc """
  Create intents from a markdown-formatted list of checkboxes
  """
  def create_from_list(
        current_user,
        obj_attrs,
        [i_intent | tail],
        tree_of_parent_ids,
        previous_indentation \\ "",
        latest_intent_id \\ nil
      ) do
    indentation =
      Enum.at(i_intent, 1)
      |> String.replace(~r/\t/, "    ")

    checked = Enum.at(i_intent, 2)

    tree_of_parent_ids =
      if latest_intent_id &&
           bit_size(indentation) > bit_size(previous_indentation) do
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

    {_, subintent} =
      Intents.create(
        current_user,
        Map.merge(
          obj_attrs,
          %{
            name: Enum.at(i_intent, 3),
            in_scope_of: [List.last(tree_of_parent_ids)],
            note: nil,
            finished: checked == "x" || checked == "X"
          }
        )
      )

    # iterate
    create_from_list(
      current_user,
      obj_attrs,
      tail,
      tree_of_parent_ids,
      indentation,
      subintent.id
    )
  end

  def create_from_list(_, _, [], _, _, _, _) do
    nil
  end

  def input_date(date) when is_binary(date) and byte_size(date) <= 10,
    do: "#{date} 00:00"

  def input_date(date), do: date

  def handle_event("create", attrs, socket) do
    # debug(attrs)
    current_user = current_user(socket)

    with obj_attrs <-
           attrs
           # |> debug()
           |> Map.merge(e(attrs, "intent", %{}))
           |> input_to_atoms()
           |> debug("input"),
         {:ok, intent} <-
           Intents.create(
             current_user,
             Map.put(obj_attrs, :due, input_date(e(obj_attrs, :due, nil)))
           ) do
      debug(intent, "created")

      case Bonfire.Common.Text.list_checkboxes(intent.note) do
        sub_intents when length(sub_intents) > 0 ->
          # debug(sub_intents)

          create_from_list(current_user, obj_attrs, sub_intents, [intent.id])

        _ ->
          nil
      end

      redir =
        if e(attrs, "redirect_after", nil) do
          e(attrs, "redirect_after", "/intent/") <> ulid!(intent)
        else
          current_url(socket, @default_path)
        end

      {:noreply, redirect_to(socket, redir)}
    end
  end

  def handle_event("status:" <> status, %{"id" => id} = attrs, socket) do
    finished? = status == "finished"

    handle_event(
      "update:status",
      Map.merge(attrs, %{finished: finished?}),
      socket
    )
  end

  def handle_event("update:" <> what, %{"id" => id} = attrs, socket) do
    with {:ok, intent} <- Intents.one(id: id),
         # TODO: switch to permissioned update
         {:ok, intent} <- Intents.update(intent, input_to_atoms(attrs)) do
      # debug(intent)

      redir =
        if e(attrs, "redirect_after", nil) and is_binary(id) do
          e(attrs, "redirect_after", "/intent/") <> id
        else
          current_url(socket, @default_path)
        end

      {:noreply, redirect_to(socket, redir)}
    end
  end

  def handle_event(
        "update:" <> what,
        attrs,
        %{assigns: %{intent: %{id: intent_id}}} = socket
      )
      when is_binary(intent_id) do
    # debug(socket)

    handle_event(
      "update:" <> what,
      Map.merge(%{"id" => intent_id}, attrs),
      socket
    )
  end

  def handle_event(
        "assign:select",
        %{"id" => assign_to, "name" => name} = attrs,
        %{assigns: %{intent: %{id: intent_id}}} = socket
      )
      when is_binary(assign_to) do
    # debug(socket)

    assign_to(
      assign_to,
      intent_id,
      path(socket.view, intent_id),
      current_user(socket),
      socket
    )
  end

  def handle_event(
        "assign:select",
        %{"id" => assign_to, "name" => name, "context_id" => intent_id} = attrs,
        %{assigns: %{process: %{id: process_id}}} = socket
      )
      when is_binary(assign_to) do
    # debug(socket)

    assign_to(
      assign_to,
      intent_id,
      path(socket.view, process_id),
      current_user(socket),
      socket
    )
  end

  def handle_event(
        "assign:select",
        %{"id" => assign_to, "name" => name, "context_id" => intent_id} = attrs,
        socket
      )
      when is_binary(assign_to) do
    # debug(socket)

    assign_to(assign_to, intent_id, nil, current_user(socket), socket)
  end

  def assign_to(assign_to, intent_id, redirect_path, current_user_id, socket) do
    assign_to_id = if assign_to == "me", do: current_user_id, else: assign_to

    with {:ok, intent} <- Intents.one(id: intent_id),
         {:ok, intent} <- Intents.update(intent, %{provider: assign_to_id}) do
      # debug(intent)
      {:noreply,
       redirect_to(
         socket,
         redirect_path || current_url(socket, @default_path)
       )}
    end
  end

  def handle_param("search", %{"term" => term} = attrs, socket) do
    with {:ok, intents} <- Intents.many([:default, search: term]) do
      {:noreply, assign_global(socket, %{intents: intents})}
    end
  end

  def handle_param("filter", %{"filter_by" => filters} = attrs, socket) do
    with {:ok, intents} <- Intents.many([:default | filters]) do
      {:noreply, assign_global(socket, %{intents: intents})}
    end
  end

  def handle_param("sort", %{"sort_by" => sort_key} = attrs, socket) do
    with {:ok, intents} <-
           Intents.many([:default, order: String.to_existing_atom(sort_key)]) do
      {:noreply, assign_global(socket, %{intents: intents})}
    end
  end

  def handle_event("delete", %{"id" => id} = attrs, socket) do
    with {:ok, intent} <- Intents.soft_delete(id, current_user(socket)) do
      # debug(intent)

      redir =
        if e(attrs, "redirect_after", nil) do
          e(attrs, "redirect_after", "/")
        else
          current_url(socket, @default_path)
        end

      {:noreply, redirect_to(socket, redir)}
    end
  end
end
