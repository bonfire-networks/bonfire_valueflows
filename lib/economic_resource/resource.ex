defmodule ValueFlows.EconomicResource do
  use Pointers.Pointable,
    otp_app: :commons_pub,
    source: "vf_resource",
    table_id: "AN0BSERVEDANDVSEFV1RES0VRC"

  import Bonfire.Repo.Changeset, only: [change_public: 1, change_disabled: 1]
  alias Ecto.Changeset

  @user Bonfire.Common.Config.get!(:user_schema)

  alias Bonfire.Quantify.Measure
  alias Bonfire.Quantify.Unit

  alias ValueFlows.Knowledge.Action
  alias ValueFlows.Knowledge.ResourceSpecification
  # alias ValueFlows.Knowledge.ProcessSpecification

  alias ValueFlows.EconomicResource

  @type t :: %__MODULE__{}

  pointable_schema do
    field(:name, :string)
    field(:note, :string)
    field(:tracking_identifier, :string)

    belongs_to(:image, CommonsPub.Uploads.Content)

    field(:classified_as, {:array, :string}, virtual: true)

    belongs_to(:conforms_to, ResourceSpecification)

    belongs_to(:current_location, Bonfire.Geolocate.Geolocation)

    belongs_to(:contained_in, EconomicResource)

    belongs_to(:state, Action, type: :string)

    belongs_to(:primary_accountable, Pointers.Pointer)

    belongs_to(:accounting_quantity, Measure, on_replace: :nilify)
    belongs_to(:onhand_quantity, Measure, on_replace: :nilify)

    belongs_to(:unit_of_effort, Unit, on_replace: :nilify)

    # belongs_to(:stage, ProcessSpecification)

    # TODO relations:
    # lot: ProductBatch

    belongs_to(:creator, @user)

    # field(:deletable, :boolean) # TODO - virtual field? how is it calculated?

    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)
    field(:is_disabled, :boolean, virtual: true, default: false)
    field(:disabled_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)

    many_to_many(:tags, Bonfire.Common.Config.maybe_schema_or_pointer(CommonsPub.Tag.Taggable),
      join_through: "bonfire_tagged",
      unique: true,
      join_keys: [pointer_id: :id, tag_id: :id],
      on_replace: :delete
    )

    timestamps(inserted_at: false)
  end

  @required ~w(name is_public)a
  @cast @required ++ ~w(note tracking_identifier current_location_id is_disabled image_id)a ++
    ~w(primary_accountable_id state_id contained_in_id unit_of_effort_id conforms_to_id current_location_id)a

  def create_changeset(
        %{} = creator,
        attrs
      ) do
    %EconomicResource{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> Changeset.change(
      creator_id: creator.id,
      is_public: true
    )
    |> common_changeset(attrs)
  end

  def update_changeset(%EconomicResource{} = resource, attrs) do
    resource
    |> Changeset.cast(attrs, @cast)
    |> common_changeset(attrs)
  end

  def change_measures(changeset, %{} = attrs) do
    measures = Map.take(attrs, measure_fields())

    Enum.reduce(measures, changeset, fn {field_name, measure}, c ->
      Changeset.put_assoc(c, field_name, measure)
    end)
  end

  def measure_fields do
    [:onhand_quantity, :accounting_quantity]
  end

  defp common_changeset(changeset, attrs) do
    changeset
    |> change_measures(attrs)
    |> change_public()
    |> change_disabled()
  end

  def context_module, do: ValueFlows.EconomicResource.EconomicResources

  def queries_module, do: ValueFlows.EconomicResource.Queries

  def follow_filters, do: [:default]
end
