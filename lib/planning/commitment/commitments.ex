defmodule ValueFlows.Planning.Commitment.Commitments do
  import Bonfire.Common.Config, only: [repo: 0]

  use Bonfire.Common.Utils,
    only: [maybe: 2, e: 3, e: 4]

  alias ValueFlows.Knowledge.Action.Actions
  alias ValueFlows.Planning.Commitment
  alias ValueFlows.Planning.Commitment.Queries

  @typep attrs :: Commitment.attrs()

  def one(filters),
    do: repo().single(Queries.query(filters))

  def by_id(id, user \\ nil),
    do: one([:default, user: user, id: id])

  def many(filters \\ []),
    do: {:ok, repo().many(Queries.query(Commitment, filters))}

  def preload_all(comm) do
    {:ok, comm} = one(id: comm.id, preload: :all)
    preload_action(comm)
  end

  def preload_action(comm),
    do: Map.put(comm, :action, Actions.action!(comm.action_id))

  @spec create(any(), attrs()) ::
          {:ok, Commitment.t()} | {:error, Changeset.t()}
  def create(creator, attrs) when is_map(attrs) do
    attrs = prep_attrs(attrs, creator)

    repo().transact_with(fn ->
      with {:ok, comm} <-
             Commitment.create_changeset(creator, attrs) |> repo().insert(),
           comm <- preload_all(%{comm | creator: creator}),
           {:ok, comm} <- ValueFlows.Util.try_tag_thing(nil, comm, attrs) do
        {:ok, comm}
      end
    end)
  end

  @spec update(struct(), String.t(), attrs()) ::
          {:ok, Commitment.t()} | {:error, any()}
  def update(user, id, changes) when is_binary(id) do
    with {:ok, comm} <- by_id(id, user) do
      do_update(comm, changes)
    end
  end

  @spec update(struct(), Commitment.t(), attrs()) ::
          {:ok, Commitment.t()} | {:error, any()}
  def update(user, comm, changes) do
    import ValueFlows.Util, only: [can?: 2]

    with :ok <- can?(user, comm) do
      do_update(comm, changes)
    end
  end

  @spec do_update(Commitment.t(), attrs()) ::
          {:ok, Commitment.t()} | {:error, any()}
  defp do_update(comm, attrs) do
    attrs = prep_attrs(attrs, Map.get(comm, :creator))

    repo().transact_with(fn ->
      with {:ok, comm} <-
             Commitment.update_changeset(comm, attrs) |> repo().update(),
           comm <- preload_all(comm),
           {:ok, comm} <- ValueFlows.Util.try_tag_thing(nil, comm, attrs) do
        {:ok, comm}
      end
    end)
  end

  @spec soft_delete(struct(), String.t()) ::
          {:ok, Commitment.t()} | {:error, Changeset.t()}
  def soft_delete(id) when is_binary(id) do
    with {:ok, comm} <- by_id(id) do
      do_soft_delete(comm)
    end
  end

  @spec soft_delete(struct(), Commitment.t()) ::
          {:ok, Commitment.t()} | {:error, Changeset.t()}
  def soft_delete(comm, user) do
    import ValueFlows.Util, only: [can?: 3]

    with :ok <- can?(user, :delete, comm) do
      do_soft_delete(comm)
    end
  end

  @spec do_soft_delete(Commitment.t()) ::
          {:ok, Commitment.t()} | {:error, Chageset.t()}
  defp do_soft_delete(comm) do
    repo().transact_with(fn ->
      with {:ok, comm} <- Bonfire.Common.Repo.Delete.soft_delete(comm) do
        {:ok, comm}
      end
    end)
  end

  @spec prep_attrs(attrs(), struct()) :: attrs()
  def prep_attrs(attrs, creator \\ nil) do
    attrs
    |> Enums.maybe_put(
      :action_id,
      e(attrs, :action, :id, e(attrs, :action, nil))
      |> ValueFlows.Knowledge.Action.Actions.id()
    )
    |> Enums.maybe_put(:input_of_id, Enums.attr_get_id(attrs, :input_of))
    |> Enums.maybe_put(:output_of_id, Enums.attr_get_id(attrs, :output_of))
    |> Enums.maybe_put(:provider_id, Util.attr_get_agent(attrs, :provider, creator))
    |> Enums.maybe_put(:receiver_id, Util.attr_get_agent(attrs, :receiver, creator))
    |> Enums.maybe_put(
      :resource_conforms_to_id,
      Enums.attr_get_id(attrs, :resource_conforms_to)
    )
    |> Enums.maybe_put(
      :resource_inventoried_as_id,
      Enums.attr_get_id(attrs, :resource_inventoried_as)
    )
    |> Enums.maybe_put(
      :context_id,
      attrs |> Map.get(:in_scope_of) |> maybe(&List.first/1)
    )
    |> Enums.maybe_put(:at_location_id, Enums.attr_get_id(attrs, :at_location))
    |> ValueFlows.Util.parse_measurement_attrs(creator)
  end
end
