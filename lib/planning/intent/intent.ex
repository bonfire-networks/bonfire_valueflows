defmodule ValueFlows.Planning.Intent do
  use Pointers.Pointable,
    otp_app: :commons_pub,
    source: "vf_intent",
    table_id: "1NTENTC0V1DBEAN0FFER0RNEED"

  import Bonfire.Repo.Changeset, only: [change_public: 1, change_disabled: 1]

  alias Ecto.Changeset
  @user Bonfire.Common.Config.get_ext(:bonfire_valueflows, :user_schema)

  alias Bonfire.Quantify.Measure

  alias ValueFlows.Knowledge.Action
  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.Proposal
  alias ValueFlows.Proposal.ProposedIntent
  alias ValueFlows.Observation.EconomicResource
  alias ValueFlows.Observation.Process

  @type t :: %__MODULE__{}

  pointable_schema do
    field(:name, :string)
    field(:note, :string)
    belongs_to(:image, CommonsPub.Uploads.Content)

    belongs_to(:provider, Pointers.Pointer)
    belongs_to(:receiver, Pointers.Pointer)

    belongs_to(:available_quantity, Measure, on_replace: :nilify)
    belongs_to(:resource_quantity, Measure, on_replace: :nilify)
    belongs_to(:effort_quantity, Measure, on_replace: :nilify)

    field(:has_beginning, :utc_datetime_usec)
    field(:has_end, :utc_datetime_usec)
    field(:has_point_in_time, :utc_datetime_usec)
    field(:due, :utc_datetime_usec)
    field(:finished, :boolean, default: false)

    # array of URI
    field(:resource_classified_as, {:array, :string})

    belongs_to(:resource_conforms_to, ResourceSpecification)
    belongs_to(:resource_inventoried_as, EconomicResource)

    belongs_to(:at_location, Bonfire.Geolocate.Geolocation)

    belongs_to(:action, Action, type: :string)

    many_to_many(:published_in, Proposal, join_through: ProposedIntent)

    belongs_to(:input_of, Process)
    belongs_to(:output_of, Process)

    # belongs_to(:agreed_in, Agreement)

    # inverse relationships
    # has_many(:satisfied_by, Satisfaction)

    belongs_to(:creator, @user)
    belongs_to(:context, Pointers.Pointer)

    # field(:deletable, :boolean) # TODO - virtual field? how is it calculated?

    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)
    field(:is_disabled, :boolean, virtual: true, default: false)
    field(:disabled_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)

    many_to_many(:tags, CommonsPub.Tag.Taggable,
      join_through: "tags_things",
      unique: true,
      join_keys: [pointer_id: :id, tag_id: :id],
      on_replace: :delete
    )

    timestamps(inserted_at: false)
  end

  @required ~w(name is_public action_id)a
  @cast @required ++
    ~w(note at_location_id is_disabled image_id context_id input_of_id output_of_id)a ++
    ~w(available_quantity_id resource_quantity_id effort_quantity_id resource_conforms_to_id resource_inventoried_as_id provider_id receiver_id)a

  def create_changeset(%{} = creator, attrs) do
    %__MODULE__{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> Changeset.change(
      creator_id: creator.id,
      is_public: true
    )
    |> common_changeset(attrs)
  end

  def update_changeset(%__MODULE__{} = intent, attrs) do
    intent
    |> Changeset.cast(attrs, @cast)
    |> common_changeset(attrs)
  end

  def measure_fields do
    [:resource_quantity, :effort_quantity, :available_quantity]
  end

  def change_measures(changeset, %{} = attrs) do
    measures = Map.take(attrs, measure_fields())

    Enum.reduce(measures, changeset, fn {field_name, measure}, c ->
      Changeset.put_assoc(c, field_name, measure)
    end)
  end

  defp common_changeset(changeset, attrs) do
    changeset
    |> change_measures(attrs)
    |> change_public()
    |> change_disabled()
    |> Changeset.foreign_key_constraint(
      :at_location_id,
      name: :vf_intent_at_location_id_fkey
    )
  end

  def context_module, do: ValueFlows.Planning.Intent.Intents

  def queries_module, do: ValueFlows.Planning.Intent.Queries

  def follow_filters, do: [:default]
end
