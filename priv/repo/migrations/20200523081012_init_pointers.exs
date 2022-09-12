defmodule Bonfire.ValueFlows.Repo.Migrations.InitPointers do
  use Ecto.Migration
  import Pointers.Migration
  import Pointers.ULID.Migration

  def up(), do: init(:up)
  def down(), do: init(:down)

  defp init(dir) do
    # this one is optional but recommended
    init_pointers_ulid_extra(dir)
    # this one is not optional
    init_pointers(dir)
  end
end
