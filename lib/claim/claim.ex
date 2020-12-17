# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Claim do
  use Pointers.Pointable,
    otp_app: :commons_pub,
    source: "vf_claim",
    table_id: "C0MM0NSPVBVA1VEF10WSC1A1MS"

  import Bonfire.Repo.Changeset, only: [change_public: 1, change_disabled: 1]

  alias Ecto.Changeset
  @user Bonfire.Common.Config.get_ext(:bonfire_valueflows, :user_schema)

  alias Bonfire.Quantify.Measure

  alias ValueFlows.Knowledge.Action
  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.Observation.EconomicEvent

  @type t :: %__MODULE__{}

  pointable_schema do
    field(:note, :string)
    field(:agreed_in, :string)
    field(:finished, :boolean)
    field(:created, :utc_datetime_usec)
    field(:due, :utc_datetime_usec)
    field(:resource_classified_as, {:array, :string}, virtual: true)

    belongs_to(:action, Action, type: :string)
    belongs_to(:provider, Pointers.Pointer)
    belongs_to(:receiver, Pointers.Pointer)
    belongs_to(:resource_quantity, Measure, on_replace: :nilify)
    belongs_to(:effort_quantity, Measure, on_replace: :nilify)

    belongs_to(:resource_conforms_to, ResourceSpecification)
    belongs_to(:triggered_by, EconomicEvent)

    # a.k.a. in_scope_of
    belongs_to(:context, Pointers.Pointer)

    # not defined in spec, used internally
    belongs_to(:creator, @user)
    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)
    field(:is_disabled, :boolean, virtual: true, default: false)
    field(:disabled_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)

    timestamps(inserted_at: false)
  end

  @required ~w(action_id)a
  @cast @required ++
    ~w(note finished agreed_in created due resource_classified_as is_disabled)a ++
    ~w(context_id resource_conforms_to_id triggered_by_id)a

  def create_changeset(%{} = creator, %{id: _} = provider, %{id: _} = receiver, attrs) do
    %__MODULE__{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.change(
      creator_id: creator.id,
      provider_id: provider.id,
      receiver_id: receiver.id,
      is_public: true
    )
    |> common_changeset(attrs)
  end

  def update_changeset(%__MODULE__{} = claim, attrs) do
    claim
    |> Changeset.cast(attrs, @cast)
    |> common_changeset(attrs)
  end

  def validate_required(changeset) do
    Changeset.validate_required(changeset, @required)
  end

  defp common_changeset(changeset, attrs) do
    changeset
    |> change_measures(attrs)
    |> change_public()
    |> change_disabled()
  end

  def change_measures(changeset, %{} = attrs) do
    measures = Map.take(attrs, measure_fields())

    Enum.reduce(measures, changeset, fn {field_name, measure}, c ->
      Changeset.put_assoc(c, field_name, measure)
    end)
  end

  def measure_fields, do: [:resource_quantity, :effort_quantity]
end
