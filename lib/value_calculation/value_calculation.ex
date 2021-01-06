# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.ValueCalculation do
  use Pointers.Pointable,
    otp_app: :commons_pub,
    source: "vf_value_calculation",
    table_id: "VA1VEF10WSVA1VECA1CV1AT10N"

  alias Ecto.Changeset
  @user Bonfire.Common.Config.get!(:user_schema)

  @type t :: %__MODULE__{}

  pointable_schema do
    field(:formula, :string)
    field(:resource_classified_as, {:array, :string}, virtual: true)

    belongs_to(:creator, @user)
    belongs_to(:context, Pointers.Pointer)
    belongs_to(:value_unit, Bonfire.Quantify.Unit)

    field(:deleted_at, :utc_datetime_usec)

    timestamps(inserted_at: false)
  end

  @required ~w(formula)a
  @cast @required ++ ~w(context_id value_unit_id)a

  def create_changeset(%{} = creator, %{} = attrs) do
    %__MODULE__{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.change(creator_id: creator.id)
    |> Changeset.validate_required(@required)
  end

  def update_changeset(%__MODULE__{} = calculation, %{} = attrs) do
    Changeset.cast(calculation, attrs, @cast)
  end
end
