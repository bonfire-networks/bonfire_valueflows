defmodule ValueFlows.Knowledge.Action do
  use Ecto.Schema

  # import Bonfire.Common.Repo.Utils, only: [change_public: 1, change_disabled: 1]

  # import Ecto.Enum

  # alias Ecto.Changeset
  # alias ValueFlows.Knowledge.Action

  # defenum label_enum, work: 0, produce: 1, consume: 2, use: 3, consume: 4, transfer: 5

  @type t :: %__MODULE__{}

  @primary_key {:id, :string, autogenerate: false}
  embedded_schema do
    # A unique verb which defines the action.
    field(:label, :string)

    # Denotes if a process input or output, or not related to a process.
    field(:input_output, :string)

    # enum: "input", "output", "notApplicable"

    # The action that should be included on the other direction of the process, for example accept with modify.
    field(:pairs_with, :string)

    # possible values: "notApplicable" (null), or any of the actions (foreign key)
    # TODO: do we want to do this as an actual Action (optional)? In the VF spec they are NamedIndividuals defined in the spec, including "notApplicable".

    # The effect of an economic event on a resource, increment, decrement, no effect, or decrement resource and increment 'to' resource
    field(:resource_effect, :string)

    # enum: "increment", "decrement", "noEffect", "decrementIncrement"

    field(:onhand_effect, :string)

    # description of the action (not part of VF)
    field(:note, :string)

    timestamps()
  end

  # @required ~w(label resource_effect)a
  # @cast @required ++ ~w(input_output pairs_with note)a

  # def create_changeset(attrs) do
  #   %Action{}
  #   |> Changeset.cast(attrs, @cast)
  #   |> Changeset.validate_required(@required)
  #   |> common_changeset()
  # end

  # def update_changeset(%Action{} = action, attrs) do
  #   action
  #   |> Changeset.cast(attrs, @cast)
  #   |> common_changeset()
  # end

  # defp common_changeset(changeset) do
  #   changeset
  # end
end
