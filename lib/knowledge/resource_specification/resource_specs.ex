# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Knowledge.ResourceSpecification.ResourceSpecifications do
  import Bonfire.Common.Utils, only: [maybe_put: 3, maybe: 2]

  @repo Application.get_env(:bonfire_valueflows, :repo_module)

  # alias Bonfire.GraphQL
  alias Bonfire.GraphQL.{Fields, Page}

  @user Application.get_env(:bonfire_valueflows, :user_schema)

  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.Knowledge.ResourceSpecification.Queries

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  @doc """
  Retrieves a single one by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def one(filters), do: @repo.single(Queries.query(ResourceSpecification, filters))

  @doc """
  Retrieves a list of them by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def many(filters \\ []), do: {:ok, @repo.all(Queries.query(ResourceSpecification, filters))}

  def fields(group_fn, filters \\ [])
      when is_function(group_fn, 1) do
    {:ok, fields} = many(filters)
    {:ok, Fields.new(fields, group_fn)}
  end

  @doc """
  Retrieves an Page of resource_specs according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(ResourceSpecification, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- @repo.transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of resource_specs according to various filters

  Used by:
  * GraphQL resolver bulk resolution
  """
  def pages(
        cursor_fn,
        group_fn,
        page_opts,
        base_filters \\ [],
        data_filters \\ [],
        count_filters \\ []
      )

  def pages(cursor_fn, group_fn, page_opts, base_filters, data_filters, count_filters) do
    Bonfire.GraphQL.Pagination.pages(
      Queries,
      ResourceSpecification,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end

  ## mutations

  @spec create(any(), attrs :: map) :: {:ok, ResourceSpecification.t()} | {:error, Changeset.t()}
  def create(%{} = creator, attrs) when is_map(attrs) do
    @repo.transact_with(fn ->
      attrs = prepare_attrs(attrs)

      with {:ok, item} <- @repo.insert(ResourceSpecification.create_changeset(creator, attrs)),
           {:ok, item} <- ValueFlows.Util.try_tag_thing(creator, item, attrs),
           act_attrs = %{verb: "created", is_local: true},
           # FIXME
           {:ok, activity} <- ValueFlows.Util.activity_create(creator, item, act_attrs),
           :ok <- ValueFlows.Util.publish(creator, item, activity, :created) do
        item = %{item | creator: creator}
        indexing_object_format(item) |> ValueFlows.Util.index_for_search()
        {:ok, item}
      end
    end)
  end


  # TODO: take the user who is performing the update
  # @spec update(%ResourceSpecification{}, attrs :: map) :: {:ok, ResourceSpecification.t()} | {:error, Changeset.t()}
  def update(%ResourceSpecification{} = resource_spec, attrs) do
    @repo.transact_with(fn ->
      resource_spec =
        @repo.preload(resource_spec, [
          :default_unit_of_effort
        ])

      attrs = prepare_attrs(attrs)
      with {:ok, resource_spec} <- @repo.update(ResourceSpecification.update_changeset(resource_spec, attrs)),
           {:ok, resource_spec} <- ValueFlows.Util.try_tag_thing(nil, resource_spec, attrs) do
        ValueFlows.Util.publish(resource_spec, :updated)
        {:ok, resource_spec}
      end
    end)
  end

  def soft_delete(%ResourceSpecification{} = resource_spec) do
    @repo.transact_with(fn ->
      with {:ok, resource_spec} <- Bonfire.Repo.Delete.soft_delete(resource_spec),
           :ok <- ValueFlows.Util.publish(resource_spec, :deleted) do
        {:ok, resource_spec}
      end
    end)
  end

  def indexing_object_format(obj) do
    # icon = CommonsPub.Uploads.remote_url_from_id(obj.icon_id)
    image = CommonsPub.Uploads.remote_url_from_id(obj.image_id)

    %{
      "index_type" => "ResourceSpecification",
      "id" => obj.id,
      # "canonicalUrl" => obj.character.canonical_url,
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
