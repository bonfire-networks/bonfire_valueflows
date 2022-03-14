# SPDX-License-Identifier: AGPL-3.0-only
if Code.ensure_loaded?(Bonfire.API.GraphQL) do
defmodule ValueFlows.Scenario.GraphQL do
  import Where

  # use Absinthe.Schema.Notation
  # import_sdl path: "lib/value_flows/graphql/schemas/scenario.gql"
end
end
