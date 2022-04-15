defmodule ValueFlows.Knowledge.ResourceSpecification do
  use Pointers.Pointable,
    otp_app: :bonfire_valueflows,
    source: "vf_resource_spec",
    table_id: "1PEC1F1CAT10NK1ND0FRES0VRC"

  import Bonfire.Repo.Common, only: [change_public: 1, change_disabled: 1]
  use Bonfire.Common.Utils, only: [maybe_put: 3, attr_get_id: 2]

  alias Ecto.Changeset

  #
  # alias ValueFlows.Knowledge.Action
  alias ValueFlows.Knowledge.ResourceSpecification
  alias Bonfire.Quantify.Unit

  @type t :: %__MODULE__{}

  pointable_schema do
    field(:name, :string)
    field(:note, :string)

    belongs_to(:image, Bonfire.Files.Media)

    # array of URI
    field(:resource_classified_as, {:array, :string}, virtual: true)

    # TODO hook up unit to contexts/resolvers
    belongs_to(:default_unit_of_effort, Unit, on_replace: :nilify)

    belongs_to(:creator, ValueFlows.Util.user_schema())
    belongs_to(:context, Pointers.Pointer)

    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)

    field(:is_disabled, :boolean, virtual: true, default: false)
    field(:disabled_at, :utc_datetime_usec)

    field(:deleted_at, :utc_datetime_usec)

    has_many(:conforming_resources, ValueFlows.EconomicResource, foreign_key: :conforms_to_id)

    many_to_many(:tags, Pointers.Pointer,
      join_through: Bonfire.Tag.Tagged,
      unique: true,
      join_keys: [id: :id, tag_id: :id],
      on_replace: :delete
    )

    timestamps(inserted_at: false)
  end

  @required ~w(name is_public)a
  @cast @required ++ ~w(note is_disabled context_id image_id)a

  def create_changeset(
        creator,
        %{id: _} = context,
        attrs
      ) do
    create_changeset(
        creator,
        attrs
      )
    |> Changeset.change(
      context_id: context.id,
    )
  end

  def create_changeset(
        %{} = creator,
        attrs
      ) do
    create_changeset(
        nil,
        attrs
      )
    |> Changeset.change(
      creator_id: creator.id,
    )
  end

  def create_changeset(
        _,
        attrs
      ) do
    %ResourceSpecification{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.change(
      default_unit_of_effort_id: attr_get_id(attrs, :default_unit_of_effort),
      is_public: true
    )
    |> Changeset.validate_required(@required)
    |> common_changeset()
  end

  def update_changeset(
        %ResourceSpecification{} = resource_spec,
        %{id: _} = context,
        attrs
      ) do
    resource_spec
    |> Changeset.cast(attrs, @cast)
    |> Changeset.change(
      context_id: context.id,
      default_unit_of_effort_id: attr_get_id(attrs, :default_unit_of_effort)
    )
    |> common_changeset()
  end

  def update_changeset(%ResourceSpecification{} = resource_spec, attrs) do
    resource_spec
    |> Changeset.cast(attrs, @cast)
    |> Changeset.change(default_unit_of_effort_id: attr_get_id(attrs, :default_unit_of_effort))
    |> common_changeset()
  end

  defp common_changeset(changeset) do
    changeset
    |> change_public()
    |> change_disabled()
  end

  def context_module, do: ValueFlows.Knowledge.ResourceSpecification.ResourceSpecifications

  def queries_module, do: ValueFlows.Knowledge.ResourceSpecification.Queries

  def follow_filters, do: [:default]
end
