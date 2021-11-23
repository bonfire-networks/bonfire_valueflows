# SPDX-License-Identifier: AGPL-3.0-only
if Code.ensure_loaded?(Bonfire.GraphQL) do
  defmodule ValueFlows.Schema do
    use Absinthe.Schema.Notation
    require Logger

    @external_resource "lib/schema.gql"

    import_types(Absinthe.Type.Custom)

    import_sdl(path: "lib/schema.gql")



  end
end
