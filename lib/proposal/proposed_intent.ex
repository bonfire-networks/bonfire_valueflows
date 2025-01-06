defmodule ValueFlows.Proposal.ProposedIntent do
  # use Bonfire.Common.Repo.Schema
  use Needle.Pointable,
    otp_app: :bonfire_valueflows,
    source: "vf_proposed_intent",
    table_id: "6VB11SHEDPR0P0SED1NTENT10N"

  alias Ecto.Changeset
  alias ValueFlows.Proposal
  alias ValueFlows.Planning.Intent

  # @type t :: %__MODULE__{}

  # table_schema "vf_proposed_intent" do
  pointable_schema do
    # Is this a reciprocal intent of this proposal? rather than primary 
    # Not meant to be used for intent matching.
    # Note: allows null
    field(:reciprocal, :boolean)
    field(:deleted_at, :utc_datetime_usec)

    # The intent which is part of this published proposal.
    belongs_to(:publishes, Intent)

    # The published proposal which this intent is part of.
    belongs_to(:published_in, Proposal)
  end

  @cast ~w(reciprocal)a

  def changeset(%Proposal{} = published_in, %Intent{} = publishes, %{} = attrs) do
    %__MODULE__{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.change(
      published_in_id: published_in.id,
      publishes_id: publishes.id
    )
  end
end
