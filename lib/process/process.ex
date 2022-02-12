defmodule ValueFlows.Process do
  use Pointers.Pointable,
    otp_app: :commons_pub,
    source: "vf_process",
    table_id: "4AYF0R1NPVTST0BEC0ME0VTPVT"

  import Bonfire.Repo.Common, only: [change_public: 1, change_disabled: 1]

  alias Ecto.Changeset

  alias ValueFlows.Process
  # alias Bonfire.Quantify.Measure

  # alias ValueFlows.Knowledge.Action
  alias ValueFlows.Knowledge.ProcessSpecification
  alias ValueFlows.Planning.Intent
  alias ValueFlows.EconomicEvent

  @type t :: %__MODULE__{}

  pointable_schema do
    field(:name, :string)
    field(:note, :string)
    # belongs_to(:image, Bonfire.Files.Media)

    field(:has_beginning, :utc_datetime_usec)
    field(:has_end, :utc_datetime_usec)

    field(:finished, :boolean, default: false)

    field(:classified_as, {:array, :string}, virtual: true)

    belongs_to(:based_on, ProcessSpecification)

    belongs_to(:context, Pointers.Pointer)

    has_many(:intended_inputs, Intent, foreign_key: :input_of_id, references: :id)
    has_many(:intended_outputs, Intent, foreign_key: :output_of_id, references: :id)

    has_many(:trace, EconomicEvent, foreign_key: :input_of_id, references: :id)
    has_many(:inputs, EconomicEvent, foreign_key: :input_of_id, references: :id)

    has_many(:track, EconomicEvent, foreign_key: :output_of_id, references: :id)
    has_many(:outputs, EconomicEvent, foreign_key: :output_of_id, references: :id)

    # TODO
    # workingAgents: [Agent!]

    # unplannedEconomicEvents(action: ID): [EconomicEvent!]

    # nextProcesses: [Process!]
    # previousProcesses: [Process!]

    # committedInputs(action: ID): [Commitment!]
    # committedOutputs(action: ID): [Commitment!]

    # plannedWithin: Plan
    # nestedIn: Scenario

    # field(:deletable, :boolean) # TODO - virtual field? how is it calculated?

    belongs_to(:creator, ValueFlows.Util.user_schema())

    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)
    field(:is_disabled, :boolean, virtual: true, default: false)
    field(:disabled_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)

    many_to_many(:tags, Pointers.Pointer,
      join_through: Bonfire.Tag.Tagged,
      unique: true,
      join_keys: [id: :id, tag_id: :id],
      on_replace: :delete
    )

    timestamps(inserted_at: false)
  end

  @required ~w(name is_public)a
  @cast @required ++ ~w(note has_beginning has_end finished is_disabled context_id based_on_id)a

  def validate_changeset(
        attrs \\ %{}
      ) do
    %Process{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.change(
      is_public: true
    )
    |> Changeset.validate_required(@required)
    |> common_changeset()
  end

  def create_changeset(
        %{} = creator,
        attrs
      ) do
    attrs
    |> validate_changeset()
    |> Changeset.change(
      creator_id: creator.id,
    )
  end

  def create_changeset(
        _,
        attrs
      ) do
    attrs
    |> validate_changeset()
  end

  def update_changeset(%Process{} = process, attrs) do
    process
    |> Changeset.cast(attrs, @cast)
    |> common_changeset()
  end

  defp common_changeset(changeset) do
    changeset
    |> change_public()
    |> change_disabled()
  end

  def context_module, do: ValueFlows.Process.Processes

  def queries_module, do: ValueFlows.Process.Queries

  def follow_filters, do: [:default]
end
