defmodule ValueFlows.Proposal.ProposedIntent do

  # use Bonfire.Repo.Schema
  use Pointers.Pointable,
    otp_app: :bonfire_valueflows,
    source: "vf_proposed_intent",
    table_id: "6VB11SHEDPR0P0SED1NTENT10N"

  alias Ecto.Changeset
  alias ValueFlows.Proposal
  alias ValueFlows.Planning.Intent

  @type t :: %__MODULE__{}

  # table_schema "vf_proposed_intent" do
  pointable_schema do
    # Note: allows null
    field(:reciprocal, :boolean)
    field(:deleted_at, :utc_datetime_usec)

    belongs_to(:publishes, Intent)
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
