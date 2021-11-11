defmodule ValueFlows.Planning.Intent do
  use Pointers.Pointable,
    otp_app: :commons_pub,
    source: "vf_intent",
    table_id: "1NTENTC0V1DBEAN0FFER0RNEED"

  import Bonfire.Repo.Changeset, only: [change_public: 1, change_disabled: 1]

  alias Ecto.Changeset


  alias Bonfire.Quantify.Measure

  alias ValueFlows.Knowledge.Action
  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.Proposal
  alias ValueFlows.Proposal.ProposedIntent
  alias ValueFlows.EconomicResource
  alias ValueFlows.Process

  @type t :: %__MODULE__{}

  pointable_schema do
    field(:name, :string)
    field(:note, :string)
    belongs_to(:image, Bonfire.Files.Media)

    belongs_to(:provider, ValueFlows.Util.user_or_org_schema())
    belongs_to(:receiver, ValueFlows.Util.user_or_org_schema())

    belongs_to(:available_quantity, Measure, on_replace: :nilify)
    belongs_to(:resource_quantity, Measure, on_replace: :nilify)
    belongs_to(:effort_quantity, Measure, on_replace: :nilify)

    field(:has_beginning, :utc_datetime_usec)
    field(:has_end, :utc_datetime_usec)
    field(:has_point_in_time, :utc_datetime_usec)
    field(:due, :utc_datetime_usec)
    field(:finished, :boolean, default: false)

    # array of URI
    field(:resource_classified_as, {:array, :string}, virtual: true)

    belongs_to(:resource_conforms_to, ResourceSpecification)
    belongs_to(:resource_inventoried_as, EconomicResource)

    belongs_to(:at_location, Bonfire.Geolocate.Geolocation)

    belongs_to(:action, Action, type: :string)

    many_to_many(:published_in, Proposal, join_through: ProposedIntent)

    belongs_to(:input_of, Process)
    belongs_to(:output_of, Process)

    # belongs_to(:agreed_in, Agreement)

    belongs_to(:creator, ValueFlows.Util.user_schema())
    belongs_to(:context, Pointers.Pointer)

    # field(:deletable, :boolean) # TODO - virtual field? how is it calculated?

    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)
    field(:is_disabled, :boolean, virtual: true, default: false)
    field(:disabled_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)

    many_to_many(:tags, Bonfire.Common.Extend.maybe_schema_or_pointer(Bonfire.Tag),
      join_through: Bonfire.Tag.Tagged,
      unique: true,
      join_keys: [pointer_id: :id, tag_id: :id],
      on_replace: :delete
    )

    timestamps(inserted_at: false)
  end

  @required ~w(name is_public action_id)a
  @cast @required ++
    ~w(note has_beginning has_end has_point_in_time due finished at_location_id is_disabled image_id context_id input_of_id output_of_id)a ++
    ~w(available_quantity_id resource_quantity_id effort_quantity_id resource_conforms_to_id resource_inventoried_as_id provider_id receiver_id)a

  def validate_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.change(
      is_public: true
    )
    |> Changeset.validate_required(@required)
    |> common_changeset(attrs)
  end

  def create_changeset(%{} = creator, attrs) do
    validate_changeset(attrs)
    |> Changeset.change(
      creator_id: creator.id,
    )
  end

  def update_changeset(%__MODULE__{} = intent, attrs) do
    intent
    |> Changeset.cast(attrs, @cast)
    |> common_changeset(attrs)
  end

  def measure_fields do
    [:resource_quantity, :effort_quantity, :available_quantity]
  end

  defp common_changeset(changeset, attrs) do
    changeset
    |> ValueFlows.Util.change_measures(attrs, measure_fields())
    |> change_public()
    |> change_disabled()
    |> validate_datetime()
    |> Changeset.foreign_key_constraint(
      :at_location_id,
      name: :vf_intent_at_location_id_fkey
    )
  end

  # validate exclusivity of datetime fields, namely:
  # has_point_in_time, has_beginning, has_end
  #
  # the logic is to allow either of these cases and nothing else
  # (due is not checked, thus allowed in each case):
  # * only has_point_in_time
  # * only has_beginning
  # * only has_end
  # * only has_beginning or has_end
  defp validate_datetime(%Changeset{valid?: false} = cset) do
    cset
  end

  defp validate_datetime(%Changeset{changes: %{has_point_in_time: _, has_beginning: _}} = cset) do
    Changeset.add_error(cset, :has_beginning, "mutually exclusive to has_point_in_time")
  end

  defp validate_datetime(%Changeset{changes: %{has_point_in_time: _, has_end: _}} = cset) do
    Changeset.add_error(cset, :has_end, "mutually exclusive to has_point_in_time")
  end

  defp validate_datetime(%Changeset{} = cset) do
    cset
  end

  def context_module, do: ValueFlows.Planning.Intent.Intents

  def queries_module, do: ValueFlows.Planning.Intent.Queries

  def follow_filters, do: [:default]
end
