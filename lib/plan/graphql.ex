# SPDX-License-Identifier: AGPL-3.0-only
if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule ValueFlows.Plan.GraphQL do
    import Untangle

    # use Absinthe.Schema.Notation
    # import_sdl path: "lib/value_flows/graphql/schemas/plan.gql"
  end
end
