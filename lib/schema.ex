# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Schema do
  use Absinthe.Schema.Notation
  require Logger

  import_types(Absinthe.Type.Custom)
  import_sdl(path: "lib/schema.gql")

end
