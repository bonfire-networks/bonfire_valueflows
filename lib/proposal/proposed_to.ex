defmodule ValueFlows.Proposal.ProposedTo do

  # use Bonfire.Common.Repo.Schema
  use Pointers.Pointable,
    otp_app: :bonfire_valueflows,
    source: "vf_proposed_to",
    table_id: "6R0P0SA1HASBEENADDRESSEDT0"

  alias Ecto.Changeset
  alias ValueFlows.Proposal

  @type t :: %__MODULE__{}

  # table_schema "vf_proposed_to" do
  pointable_schema do
    field(:deleted_at, :utc_datetime_usec)
    belongs_to(:proposed_to, Pointer)
    belongs_to(:proposed, Proposal)
  end

  def changeset(%{id: _} = proposed_to, %Proposal{} = proposed) do
    %__MODULE__{}
    |> Changeset.cast(%{}, [])
    |> Changeset.change(
      proposed_to_id: proposed_to.id,
      proposed_id: proposed.id
    )
  end
end
