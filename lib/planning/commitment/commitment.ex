defmodule ValueFlows.Planning.Commitment do
  use Needle.Pointable,
    otp_app: :bonfire,
    source: "vf_commitment",
    table_id: "40MM1TMENTED95D6694555B6E8"

  alias Ecto.Changeset

  alias Bonfire.Quantify.Measure
  alias Bonfire.Geolocate.Geolocation
  alias ValueFlows.Knowledge.Action
  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.EconomicResource
  alias ValueFlows.Process

  # @type t :: %__MODULE__{}

  pointable_schema do
    belongs_to(:action, Action, type: :string)

    belongs_to(:input_of, Process)
    belongs_to(:output_of, Process)

    belongs_to(:provider, ValueFlows.Util.user_or_org_schema())
    belongs_to(:receiver, ValueFlows.Util.user_or_org_schema())

    field(:resource_classified_as, {:array, :string}, virtual: true)
    belongs_to(:resource_conforms_to, ResourceSpecification)
    belongs_to(:resource_inventoried_as, EconomicResource)

    belongs_to(:resource_quantity, Measure, on_replace: :nilify)
    belongs_to(:effort_quantity, Measure, on_replace: :nilify)

    field(:has_beginning, :utc_datetime_usec)
    field(:has_end, :utc_datetime_usec)
    field(:has_point_in_time, :utc_datetime_usec)
    field(:due, :utc_datetime_usec)
    # for the field `created`, use Needle.ULID.timestamp/1

    field(:finished, :boolean, default: false)

    # should this be a virtual field?
    field(:deletable, :boolean, default: false)

    field(:note, :string)
    field(:agreed_in, :string)

    # inScopeOf
    belongs_to(:context, Needle.Pointer)

    # belongs_to :clause_of, Agreement

    belongs_to(:at_location, Geolocation)

    # belongs_to :independent_demand_of, Plan

    belongs_to(:creator, ValueFlows.Util.user_schema())

    field(:is_public, :boolean, virtual: true)
    field(:is_disabled, :boolean, virtual: true, default: false)
    field(:published_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)
    field(:disabled_at, :utc_datetime_usec)

    timestamps(inserted_at: false)
  end

  @type attrs :: %{required(binary()) => term()} | %{required(atom()) => term()}

  @required ~w[action_id]a
  @cast @required ++
          ~w[
      action_id input_of_id output_of_id provider_id receiver_id
      resource_classified_as resource_conforms_to_id resource_inventoried_as_id
      resource_quantity_id effort_quantity_id
      has_beginning has_end has_point_in_time due
      finished note agreed_in
      context_id at_location_id
      deleted_at disabled_at
    ]a

  @spec create_changeset(struct(), attrs()) :: Changeset.t()
  def create_changeset(creator, attrs) do
    %__MODULE__{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> Changeset.change(is_public: true)
    |> Changeset.change(creator_id: creator.id)
    |> common_changeset(attrs)
  end

  @spec create_changeset(t(), attrs()) :: Changeset.t()
  def update_changeset(comm, attrs) do
    comm
    |> Changeset.cast(attrs, @cast)
    |> common_changeset(attrs)
  end

  @spec common_changeset(Chageset.t(), attrs()) :: Changeset.t()
  defp common_changeset(cset, attrs) do
    import Bonfire.Common.Repo.Utils,
      only: [change_public: 1, change_disabled: 1]

    cset
    |> ValueFlows.Util.change_measures(attrs, measure_fields())
    |> change_public()
    |> change_disabled()
    |> Changeset.foreign_key_constraint(
      :at_location_id,
      name: :vf_commitment_at_location_id_fkey
    )
  end

  def measure_fields(),
    do: [:resource_quantity, :effort_quantity]

  @behaviour Bonfire.Common.SchemaModule
  def context_module(),
    do: ValueFlows.Planning.Commitment.Commitments

  def query_module(),
    do: ValueFlows.Planning.Commitment.Queries

  def follow_filters(),
    do: [:default]
end
