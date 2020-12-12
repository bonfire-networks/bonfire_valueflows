defmodule ValueFlows.Knowledge.ProcessSpecification do
  use Pointers.Pointable,
    otp_app: :commons_pub,
    source: "vf_process_spec",
    table_id: "ASPEC1F1CAT10NF0RPR0CESSES"

  import Bonfire.Repo.Changeset, only: [change_public: 1, change_disabled: 1]

  alias Ecto.Changeset
  @user Application.get_env(:bonfire_valueflows, :user_schema)

  alias ValueFlows.Knowledge.ProcessSpecification

  @type t :: %__MODULE__{}

  pointable_schema do
    field(:name, :string)
    field(:note, :string)

    field(:classified_as, {:array, :string}, virtual: true)

    belongs_to(:context, Pointers.Pointer)

    belongs_to(:creator, @user)

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

  @required ~w(name is_public)a
  @cast @required ++ ~w(note classified_as is_disabled context_id)a

  def create_changeset(
        %{} = creator,
        attrs
      ) do
    %ProcessSpecification{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> Changeset.change(
      creator_id: creator.id,
      is_public: true
    )
    |> common_changeset()
  end

  def update_changeset(%ProcessSpecification{} = process_spec, attrs) do
    process_spec
    |> Changeset.cast(attrs, @cast)
    |> common_changeset()
  end

  defp common_changeset(changeset) do
    changeset
    |> change_public()
    |> change_disabled()
  end

  def context_module, do: ValueFlows.Knowledge.ProcessSpecification.ProcessSpecifications

  def queries_module, do: ValueFlows.Knowledge.ProcessSpecification.Queries

  def follow_filters, do: [:default]
end
