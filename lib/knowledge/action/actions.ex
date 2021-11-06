defmodule ValueFlows.Knowledge.Action.Actions do
  # @on_load :actions_map

  @default_actions ~w(accept cite consume deliver-service dropoff lower modify move pack pickup produce raise transfer transfer-all-rights transfer-custody unpack use work)

  # NOTE: you can define new actions below, but do not add them to @default_actions above unless they are already defined at https://w3id.org/valueflows

  def actions_map do
    %{
      "dropoff" => %ValueFlows.Knowledge.Action{
        id: "dropoff",
        label: "dropoff",
        resource_effect: "noEffect",
        onhand_effect: "noEffect",
        note:
          "transported resource or person leaves the process, the same resource will appear in input",
        input_output: "output",
        pairs_with: "pickup"
      },
      "pickup" => %ValueFlows.Knowledge.Action{
        id: "pickup",
        label: "pickup",
        resource_effect: "noEffect",
        onhand_effect: "noEffect",
        note:
          "transported resource or person enters the process, the same resource will appear in output",
        input_output: "input",
        pairs_with: "dropoff"
      },
      "consume" => %ValueFlows.Knowledge.Action{
        id: "consume",
        label: "consume",
        resource_effect: "decrement",
        onhand_effect: "decrement",
        note:
          "for example an ingredient or component composed into the output, after the process the ingredient is gone",
        input_output: "input"
      },
      "use" => %ValueFlows.Knowledge.Action{
        id: "use",
        label: "use",
        resource_effect: "noEffect",
        onhand_effect: "noEffect",
        note: "for example a tool used in process, after the process, the tool still exists",
        input_output: "input"
      },
      "work" => %ValueFlows.Knowledge.Action{
        id: "work",
        label: "work",
        resource_effect: "noEffect",
        onhand_effect: "noEffect",
        note: "labor power towards a process",
        input_output: "input"
      },
      "cite" => %ValueFlows.Knowledge.Action{
        id: "cite",
        label: "cite",
        resource_effect: "noEffect",
        onhand_effect: "noEffect",
        note:
          "for example a design file, neither used nor consumed, the file remains available at all times",
        input_output: "input"
      },
      "produce" => %ValueFlows.Knowledge.Action{
        id: "produce",
        label: "produce",
        resource_effect: "increment",
        onhand_effect: "increment",
        note: "new resource created in that process or an existing stock resource added to",
        input_output: "output"
      },
      "accept" => %ValueFlows.Knowledge.Action{
        id: "accept",
        label: "accept",
        resource_effect: "noEffect",
        onhand_effect: "decrement",
        note:
          "in processes like repair or modification or testing, the same resource will appear in output with vf:modify verb",
        input_output: "input",
        pairs_with: "modify"
      },
      "modify" => %ValueFlows.Knowledge.Action{
        id: "modify",
        label: "modify",
        resource_effect: "noEffect",
        onhand_effect: "increment",
        note:
          "in processes like repair or modification or testing, the same resource will appear in input with vf:accept verb",
        input_output: "output",
        pairs_with: "accept"
      },
      "deliver-service" => %ValueFlows.Knowledge.Action{
        id: "deliver-service",
        label: "deliver-service",
        resource_effect: "noEffect",
        onhand_effect: "noEffect",
        note:
          "new service produced and delivered (being a service implies that an agent actively receives the service",
        input_output: "output"
      },
      "transfer-all-rights" => %ValueFlows.Knowledge.Action{
        id: "transfer-all-rights",
        label: "transfer-all-rights",
        resource_effect: "decrementIncrement",
        onhand_effect: "noEffect",
        note:
          "give full (in the human realm) rights and responsibilities to another agent, without transferring physical custody"
      },
      "transfer-custody" => %ValueFlows.Knowledge.Action{
        id: "transfer-custody",
        label: "transfer-custody",
        resource_effect: "noEffect",
        onhand_effect: "decrementIncrement",
        note:
          "give physical custody and control of a resource, without full accounting or ownership rights"
      },
      "transfer" => %ValueFlows.Knowledge.Action{
        id: "transfer",
        label: "transfer",
        resource_effect: "decrementIncrement",
        onhand_effect: "decrementIncrement",
        note: "give full rights and responsibilities plus physical custody"
      },
      "move" => %ValueFlows.Knowledge.Action{
        id: "move",
        label: "move",
        resource_effect: "decrementIncrement",
        onhand_effect: "decrementIncrement",
        note: "change location and/or identity of a resource with no change of agent"
      },
      "raise" => %ValueFlows.Knowledge.Action{
        id: "raise",
        label: "raise",
        resource_effect: "increment",
        onhand_effect: "increment",
        note: "adjusts a quantity up based on a beginning balance or inventory count"
      },
      "lower" => %ValueFlows.Knowledge.Action{
        id: "lower",
        label: "lower",
        resource_effect: "decrement",
        onhand_effect: "decrement",
        note: "adjusts a quantity down based on a beginning balance or inventory count"
      }
    }
  end

  def id(label) do
    with {:ok, action} <- action(label) do
      action.id
    else
      _ -> nil
    end
  end

  def action!(label) do
    with {:ok, action} <- action(label) do
      action
    else
      _ -> nil
    end
  end


  def action(%{id: label}), do: action(label)
  def action(%{label: label}), do: action(label)
  def action("https://w3id.org/valueflows#"<>label), do: action(label)

  def action(label) when is_atom(label) do
    action(Atom.to_string(label))
  end

  def action(label) do
    case actions_map()[label] do
      nil ->
        {:error, :not_found}

      action ->
        {:ok, action}
    end
  end

  def actions_list() do
    Map.values(actions_map())
  end

  def default_actions, do: @default_actions
end
