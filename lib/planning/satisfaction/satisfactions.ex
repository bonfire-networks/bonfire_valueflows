defmodule ValueFlows.Planning.Satisfaction.Satisfactions do
  import Bonfire.Common.Config, only: [repo: 0]

  alias Ecto.Changeset
  alias ValueFlows.Planning.{Satisfaction, Satisfaction.Queries}

  @typep attrs :: Satisfaction.attrs

  def one(filters),
    do: repo().single(Queries.query(filters))

  def by_id(id, user \\ nil),
    do: one([:default, user: user, id: id])

  def preload_all(%{id: id}) do
    {:ok, satis} = one(id: id, preload: :all)
    satis
  end

  def many(filters \\ []),
    do: {:ok, repo().many(Queries.query(filters))}

  @spec create(struct(), attrs()) ::
          {:ok, Satisfaction.t()} | {:error, Changeset.t()}
  def create(creator, attrs) do
    attrs = prep_attrs(attrs, creator)

    repo().transact_with(fn ->
      with {:ok, satis} <- Satisfaction.create_changeset(creator, attrs) |> repo().insert(),
           satis = preload_all(%{satis | creator: creator}) do
        {:ok, satis}
      end
    end)
  end

  @spec update(struct(), String.t(), attrs()) ::
          {:ok, Satisfaction.t()} | {:error, any()}
  def update(user, id, changes) when is_binary(id) do
    with {:ok, satis} <- by_id(id, user) do
      do_update(satis, changes)
    end
  end

  @spec update(struct(), Satisfaction.t(), attrs()) ::
          {:ok, Satisfaction.t()} | {:error, any()}
  def update(user, satis, changes) do
    import ValueFlows.Util, only: [ensure_edit_permission: 2]

    with :ok <- ensure_edit_permission(user, satis) do
      do_update(satis, changes)
    end
  end

  @spec do_update(Satisfaction.t(), attrs()) ::
          {:ok, Satisfaction.t()} | {:error, any()}
  defp do_update(satis, attrs) do
    attrs = prep_attrs(attrs, Map.get(satis, :creator))

    repo().transact_with(fn ->
      with {:ok, satis} <- repo().update(Satisfaction.update_changeset(satis, attrs)) do
        satis = preload_all(satis)
        {:ok, satis}
      end
    end)
  end

  @spec soft_delete(struct(), String.t()) ::
          {:ok, Satisfaction.t()} | {:error, Changeset.t()}
  def soft_delete(user, id) when is_binary(id) do
    with {:ok, satis} <- by_id(id, user) do
      do_soft_delete(satis)
    end
  end

  @spec soft_delete(struct(), Satisfaction.t()) ::
          {:ok, Satisfaction.t()} | {:error, Changeset.t()}
  def soft_delete(user, satis) do
    import ValueFlows.Util, only: [ensure_edit_permission: 2]

    with :ok <- ensure_edit_permission(user, satis) do
      do_soft_delete(satis)
    end
  end

  @spec do_soft_delete(Satisfaction.t()) ::
          {:ok, Satisfaction.t()} | {:error, Chageset.t()}
  defp do_soft_delete(satis) do
    repo().transact_with(fn ->
      with {:ok, satis} <- Bonfire.Repo.Delete.soft_delete(satis) do
        {:ok, satis}
      end
    end)
  end

  @spec prep_attrs(attrs(), struct()) :: attrs()
  defp prep_attrs(attrs, creator) do
    use Bonfire.Common.Utils, only: [maybe_put: 3, attr_get_id: 2]

    attrs
    |> maybe_put(:satisfies_id, attr_get_id(attrs, :satisfies))
    |> maybe_put(:satisfied_by_id, attr_get_id(attrs, :satisfied_by))
    |> ValueFlows.Util.parse_measurement_attrs(creator)
  end
end
