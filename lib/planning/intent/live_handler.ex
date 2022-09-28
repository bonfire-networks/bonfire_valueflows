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
    current_user = current_user_required(socket)

    with obj_attrs <-
           attrs
           # |> debug()
           |> Map.merge(e(attrs, "intent", %{}))
           |> input_to_atoms()
           |> debug("intent input"),
         {:ok, %{id: id} = intent} <-
           Intents.create(
             current_user,
             obj_attrs
             |> Map.put(:due, input_date(e(obj_attrs, :due, nil)))
             |> Map.put_new(:receiver, current_user)
           ) do
      debug(intent, "intent created")

      case Bonfire.Common.Text.list_checkboxes(intent.note) do
        sub_intents when length(sub_intents) > 0 ->
          # debug(sub_intents)

          create_from_list(current_user, obj_attrs, sub_intents, [id])

        _ ->
          nil
      end

      redir =
        if e(attrs, "redirect_after", nil) do
          e(attrs, "redirect_after", "/intent") <> "/" <> id
        else
          current_url(socket, @default_path)
        end

      {:noreply, redirect_to(socket, redir)}
    end
  end

  def handle_event("status:" <> status, %{"id" => id} = attrs, socket) do
    update(:label, id, Map.merge(attrs, %{finished: status == "finished"}), socket)
  end

  def handle_event(
        "update:" <> what,
        %{"field" => field, "id" => value, "context_id" => intent_id} = attrs,
        socket
      ) do
    update(what, intent_id, Map.put(%{}, field, value), socket)
  end

  def handle_event("update:" <> what, %{"id" => id} = attrs, socket) do
    update(what, id, attrs, socket)
  end

  def handle_event("update", %{"id" => id} = attrs, socket) do
    update(:edit, id, attrs, socket)
  end

  def handle_event(
        "update:" <> what,
        attrs,
        %{assigns: %{intent: %{id: _} = intent}} = socket
      ) do
    update(what, intent, attrs, socket)
  end

  def handle_event(
        "update",
        attrs,
        %{assigns: %{intent: %{id: _} = intent}} = socket
      ) do
    update(:edit, intent, attrs, socket)
  end

  def handle_event(
        "assign:select",
        %{"id" => assign_to, "name" => name} = attrs,
        %{assigns: %{intent: %{id: _} = intent}} = socket
      ) do
    assign_to(
      assign_to,
      intent,
      socket
    )
  end

  def handle_event(
        "assign:select",
        %{"id" => assign_to, "name" => name, "context_id" => intent_id} = attrs,
        socket
      ) do
    # debug(socket)

    assign_to(
      assign_to,
      intent_id,
      socket
    )
  end

  def handle_event(
        "assign:select",
        %{"id" => assign_to, "name" => name, "context_id" => intent_id} = attrs,
        %{assigns: %{intent: %{id: intent_id}}} = socket
      ) do
    # debug(socket)

    assign_to(assign_to, intent_id, socket)
  end

  def handle_event(
        "assign:select",
        %{"id" => assign_to, "field" => field, "context_id" => intent_id} = attrs,
        socket
      ) do
    # debug(socket)

    assign_to(assign_to, intent_id, socket, maybe_to_atom(field))
  end

  def handle_event(
        "assign:unset",
        %{"field" => field, "context_id" => intent_id} = attrs,
        socket
      ) do
    # debug(socket)

    assign_to(nil, intent_id, socket, maybe_to_atom(field))
  end

  defp update(what, intent, attrs, socket) do
    attrs =
      input_to_atoms(attrs)
      |> maybe_put(:due, input_date(e(attrs, :due, nil)))
      |> debug("attrs")

    with {:ok, intent} <-
           Intents.update(current_user_required(socket), intent, attrs, update_verb(what)) do
      debug(intent, "updated")

      {:noreply,
       socket
       |> assign(intent: intent)}

      id = ulid(intent)

      if e(attrs, "redirect_after", nil) && is_binary(id) do
        redir = e(attrs, "redirect_after", "/intent") <> "/" <> id
        {:noreply, redirect_to(socket, redir)}
      else
        # current_url(socket, @default_path)
        {:noreply,
         socket
         |> assign(intent: intent)}

        # send_self(socket, intent: intent)
      end
    end
  end

  def assign_to(assign_to, intent, socket, field \\ :provider) do
    assign_to_id = if assign_to == "me", do: current_user_required(socket), else: assign_to

    update(:assign, intent, Map.put(%{}, field || :provider, assign_to_id), socket)
  end

  def update_verb("due"), do: :schedule
  def update_verb("assign"), do: :assign
  def update_verb("provider"), do: :assign
  def update_verb("status"), do: :label
  def update_verb(verb) when is_atom(verb), do: verb
  def update_verb(_), do: :edit

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

  # def handle_event("delete", %{"id" => id} = attrs, socket) do
  #   with {:ok, intent} <- Intents.soft_delete(id, current_user_required(socket)) do
  #     # debug(intent)

  #     redir =
  #       if e(attrs, "redirect_after", nil) do
  #         e(attrs, "redirect_after", "/")
  #       else
  #         current_url(socket, @default_path)
  #       end

  #     {:noreply, redirect_to(socket, redir)}
  #   end
  # end
end
