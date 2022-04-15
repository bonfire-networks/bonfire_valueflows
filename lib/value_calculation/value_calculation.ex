# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.ValueCalculation do
  use Pointers.Pointable,
    otp_app: :bonfire_valueflows,
    source: "vf_value_calculation",
    table_id: "3A1VEF10WSVA1VECA1CV1AT10N"

  alias Ecto.Changeset


  @type t :: %__MODULE__{}

  pointable_schema do
    field(:name, :string)
    field(:note, :string)
    field(:formula, :string)
    field(:resource_classified_as, {:array, :string}, virtual: true)

    belongs_to(:creator, ValueFlows.Util.user_schema())
    belongs_to(:context, Pointers.Pointer)
    belongs_to(:value_unit, Bonfire.Quantify.Unit)
    belongs_to(:action, ValueFlows.Actions.Action, type: :string)
    belongs_to(:value_action, ValueFlows.Actions.Action, type: :string)
    belongs_to(:resource_conforms_to, ValueFlows.Knowledge.ResourceSpecification)
    belongs_to(:value_resource_conforms_to, ValueFlows.Knowledge.ResourceSpecification)

    field(:deleted_at, :utc_datetime_usec)

    timestamps(inserted_at: false)
  end

  @required ~w(formula action_id value_action_id value_unit_id)a
  @cast @required ++ ~w(name note context_id resource_conforms_to_id value_resource_conforms_to_id)a

  def create_changeset(%{} = creator, %{} = attrs) do
    %__MODULE__{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.change(creator_id: creator.id)
    |> Changeset.validate_required(@required)
  end

  def update_changeset(%__MODULE__{} = calculation, %{} = attrs) do
    Changeset.cast(calculation, attrs, @cast)
  end

  def queries_module, do: ValueFlows.ValueCalculation.Queries
  def follow_filters, do: [:default]
end
