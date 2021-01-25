defmodule ValueFlows.EconomicEvent do
  use Pointers.Pointable,
    otp_app: :commons_pub,
    source: "vf_event",
    table_id: "ACTVA10BSERVEDF10WS0FVA1VE"

  import Bonfire.Repo.Changeset, only: [change_public: 1, change_disabled: 1]

  alias Ecto.Changeset
  @user Bonfire.Common.Config.get!(:user_schema)

  alias ValueFlows.Knowledge.Action
  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.EconomicEvent
  alias ValueFlows.EconomicResource
  alias ValueFlows.Process
  alias ValueFlows.ValueCalculation

  alias Bonfire.Quantify.Measure

  @type t :: %__MODULE__{}

  pointable_schema do
    field(:note, :string)

    # TODO: link to Agreement?
    field(:agreed_in, :string)

    field(:has_beginning, :utc_datetime_usec)
    field(:has_end, :utc_datetime_usec)
    field(:has_point_in_time, :utc_datetime_usec)

    belongs_to(:action, Action, type: :string)

    belongs_to(:input_of, Process)
    belongs_to(:output_of, Process)

    belongs_to(:provider, Pointers.Pointer)
    belongs_to(:receiver, Pointers.Pointer)

    belongs_to(:resource_inventoried_as, EconomicResource)
    belongs_to(:to_resource_inventoried_as, EconomicResource)

    field(:resource_classified_as, {:array, :string}, virtual: true)

    belongs_to(:resource_conforms_to, ResourceSpecification)

    belongs_to(:resource_quantity, Measure, on_replace: :nilify)
    belongs_to(:effort_quantity, Measure, on_replace: :nilify)

    belongs_to(:context, Pointers.Pointer)

    belongs_to(:at_location, Bonfire.Geolocate.Geolocation)

    belongs_to(:triggered_by, EconomicEvent)

    # belongs_to(:calculated_using, ValueCalculation)

    # TODO:
    # track: [ProductionFlowItem!]
    # trace: [ProductionFlowItem!]
    # realizationOf: Agreement
    # appreciationOf: [Appreciation!]
    # appreciatedBy: [Appreciation!]
    # fulfills: [Fulfillment!]
    # satisfies: [Satisfaction!]
    # field(:deletable, :boolean) # TODO - virtual field? how is it calculated?

    belongs_to(:creator, @user)

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

  @required ~w(action_id provider_id receiver_id is_public)a
  @cast @required ++
          ~w(note resource_classified_as agreed_in has_beginning has_end has_point_in_time is_disabled)a ++
          ~w(input_of_id output_of_id resource_conforms_to_id resource_inventoried_as_id to_resource_inventoried_as_id)a ++
          ~w(triggered_by_id at_location_id context_id)a

  def create_changeset(
        %{} = creator,
        attrs
      ) do
    %EconomicEvent{}
    |> Changeset.cast(attrs, @cast)
    # |> Changeset.validate_required(@required)
    |> Changeset.change(
      creator_id: creator.id,
      is_public: true
    )
    |> change_measures(attrs)
    |> common_changeset()
  end

  def create_changeset_validate(cs) do
    cs
    |> Changeset.validate_required(@required)
  end

  def update_changeset(%EconomicEvent{} = event, attrs) do
    event
    |> Changeset.cast(attrs, @cast)
    |> change_measures(attrs)
    |> common_changeset()
  end

  def change_measures(changeset, %{} = attrs) do
    measures = Map.take(attrs, measure_fields())

    Enum.reduce(measures, changeset, fn {field_name, measure}, c ->
      Changeset.put_assoc(c, field_name, measure)
    end)
  end

  def measure_fields do
    [:resource_quantity, :effort_quantity]
  end

  defp common_changeset(changeset) do
    changeset
    |> change_public()
    |> change_disabled()
    |> Changeset.foreign_key_constraint(
      :resource_inventoried_as_id,
      name: :vf_event_resource_inventoried_as_id_fkey
    )
    |> Changeset.foreign_key_constraint(
      :to_resource_inventoried_as_id,
      name: :vf_event_to_resource_inventoried_as_id_fkey
    )
  end

  def context_module, do: ValueFlows.EconomicEvent.EconomicEvents

  def queries_module, do: ValueFlows.EconomicEvent.Queries

  def follow_filters, do: [:default]
end
