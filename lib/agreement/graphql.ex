# SPDX-License-Identifier: AGPL-3.0-only
if Code.ensure_loaded?(Bonfire.API.GraphQL) do
defmodule ValueFlows.Agreement.GraphQL do
  import Untangle

  # use Absinthe.Schema.Notation
  # import_sdl path: "lib/value_flows/graphql/schemas/agreement.gql"
end
end
