# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Knowledge.ResourceSpecification.ResourceSpecifications do
  import Bonfire.Common.Utils, only: [maybe_put: 3, maybe: 2]

  import Bonfire.Common.Config, only: [repo: 0]

  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.Knowledge.ResourceSpecification.Queries

  @search_type "ValueFlows.ResourceSpecification"

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  @doc """
  Retrieves a single one by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def one(filters), do: repo().single(Queries.query(ResourceSpecification, filters))

  @doc """
  Retrieves a list of them by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def many(filters \\ []), do: {:ok, many!(filters)}
  def many!(filters \\ []), do: repo().many(Queries.query(ResourceSpecification, filters))

  def search(search) do
   ValueFlows.Util.maybe_search(search, @search_type) || many!(autocomplete: search)
  end

  def maybe_get(%{resource_conforms_to_id: id}) when is_binary(id) do
    with {:ok, fetched} <- one(id: id) do
      fetched
    else _ ->
      nil
    end
  end
  def maybe_get(_), do: nil

  ## mutations

  @spec create(any(), attrs :: map) :: {:ok, ResourceSpecification.t()} | {:error, Changeset.t()}
  def create(%{} = creator, attrs) when is_map(attrs) do
    repo().transact_with(fn ->
      attrs = prepare_attrs(attrs)

      with {:ok, item} <- repo().insert(ResourceSpecification.create_changeset(creator, attrs)),
           item <- %{item | creator: creator},
           {:ok, item} <- ValueFlows.Util.try_tag_thing(creator, item, attrs),
           {:ok, activity} <- ValueFlows.Util.publish(creator, :define, item) do

        indexing_object_format(item) |> ValueFlows.Util.index_for_search()

        {:ok, item}
      end
    end)
  end


  # TODO: take the user who is performing the update
  # @spec update(%ResourceSpecification{}, attrs :: map) :: {:ok, ResourceSpecification.t()} | {:error, Changeset.t()}
  def update(%ResourceSpecification{} = resource_spec, attrs) do
    repo().transact_with(fn ->
      resource_spec =
        repo().preload(resource_spec, [
          :default_unit_of_effort
        ])

      attrs = prepare_attrs(attrs)
      with {:ok, resource_spec} <- repo().update(ResourceSpecification.update_changeset(resource_spec, attrs)),
           {:ok, resource_spec} <- ValueFlows.Util.try_tag_thing(nil, resource_spec, attrs) do

        ValueFlows.Util.publish(resource_spec, :update)

        {:ok, resource_spec}
      end
    end)
  end

  def soft_delete(%ResourceSpecification{} = resource_spec) do
    repo().transact_with(fn ->
      with {:ok, resource_spec} <- Bonfire.Repo.Delete.soft_delete(resource_spec),
           {:ok, _} <- ValueFlows.Util.publish(resource_spec, :deleted) do
        {:ok, resource_spec}
      end
    end)
  end

  def indexing_object_format(obj) do

    image = ValueFlows.Util.image_url(obj)

    %{
      "index_type" => @search_type,
      "id" => obj.id,
      # "url" => obj.character.canonical_url,
      # "icon" => icon,
      "image" => image,
      "name" => obj.name,
      "summary" => Map.get(obj, :note),
      "published_at" => obj.published_at,
      "creator" => ValueFlows.Util.indexing_format_creator(obj)
      # "index_instance" => URI.parse(obj.character.canonical_url).host, # home instance of object
    }
  end


  defp prepare_attrs(attrs) do
    attrs
    |> maybe_put(:context_id,
      attrs |> Map.get(:in_scope_of) |> maybe(&List.first/1)
    )
  end
end
