# SPDX-License-Identifier: AGPL-3.0-only
if Code.ensure_loaded?(Bonfire.API.GraphQL) do
defmodule ValueFlows.Knowledge.Action.GraphQL do


  import Where

  # use Absinthe.Schema.Notation
  # import_sdl path: "lib/value_flows/graphql/schemas/knowledge.gql"

  def action(%{id: id}, _) do
    # {:ok, Simulate.action()}
    ValueFlows.Knowledge.Action.Actions.action(id)
  end

  def all_actions(_, _) do
    {:ok, ValueFlows.Knowledge.Action.Actions.actions_list()}
    # {:ok, long_list(&Simulate.action/0)}
  end

  def action_edge(%{action_id: id}, _, _) when not is_nil(id) do
    action(%{id: id}, nil)
  end

  def action_edge(_, _, _) do
    {:ok, nil}
  end
end
end
