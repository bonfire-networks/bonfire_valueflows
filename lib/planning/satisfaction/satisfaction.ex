defmodule ValueFlows.Planning.Satisfaction do
  use Pointers.Pointable,
    otp_app: :bonfire,
    source: "vf_satisfaction",
    table_id: "1AT1SFACT10N4F8994AD427E7B"

  alias Ecto.Changeset
  alias ValueFlows.EconomicEvent
  alias ValueFlows.Planning.{Intent, Commitment}
  alias Bonfire.Quantify.Measure
  alias Pointers.Pointer

  @type t :: %__MODULE__{
    id: String.t(),
    satisfies: Intent.t(),
    satisfies_id: String.t(),
    satisfied_by: EconomicEvent.t() | Commitment.t(),
    satisfied_by_id: String.t(),
    resource_quantity: Measure.t(),
    resource_quantity_id: String.t(),
    effort_quantity: Measure.t(),
    effort_quantity: String.t(),
    note: String.t(),
    creator: struct(),
    creator_id: String.t(),
    is_public: boolean(),
    is_disabled: boolean(),
    published_at: DateTime.t(),
    deleted_at: DateTime.t(),
    disabled_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  pointable_schema do
    belongs_to :satisfies, Intent
    belongs_to :satisfied_by, Pointer # Commitment or EconomicEvent
    belongs_to :resource_quantity, Measure, on_replace: :nilify
    belongs_to :effort_quantity, Measure, on_replace: :nilify

    field :note, :string

    belongs_to :creator, ValueFlows.Util.user_schema()

    field :is_public, :boolean, virtual: true
    field :is_disabled, :boolean, virtual: true, default: false
    field :published_at, :utc_datetime_usec
    field :deleted_at, :utc_datetime_usec
    field :disabled_at, :utc_datetime_usec

    timestamps inserted_at: false
  end

  @type attrs :: %{required(binary()) => term()} | %{required(atom()) => term()}

  @reqr ~w[satisfies_id satisfied_by_id]a
  @cast @reqr ++
    ~w[
      resource_quantity_id effort_quantity_id note
      disabled_at
    ]a

  @spec create_changeset(struct(), attrs()) :: Changeset.t()
  def create_changeset(creator, attrs) do
    %__MODULE__{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@reqr)
    |> Changeset.change(is_public: true, creator_id: creator.id)
    |> common_changeset(attrs)
  end

  @spec update_changeset(t(), attrs()) :: Changeset.t()
  def update_changeset(satis, attrs) do
    satis
    |> Changeset.cast(attrs, @cast)
    |> common_changeset(attrs)
  end

  @spec common_changeset(Chageset.t(), attrs()) :: Changeset.t()
  defp common_changeset(cset, attrs) do
    import Bonfire.Repo.Common, only: [change_public: 1, change_disabled: 1]

    cset
    |> ValueFlows.Util.change_measures(attrs, measure_fields())
    |> change_public()
    |> change_disabled()
  end

  def measure_fields(),
    do: [:resource_quantity, :effort_quantity]

  def context_module(),
    do: ValueFlows.Planning.Satisfaction.Satisfactions

  def queries_module(),
    do: ValueFlows.Planning.Satisfaction.Queries

  def follow_filters(),
    do: [:default]
end
