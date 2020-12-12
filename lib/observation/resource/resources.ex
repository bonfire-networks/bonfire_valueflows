# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Observation.EconomicResource.EconomicResources do
  import Bonfire.Common.Utils, only: [maybe_put: 3, attr_get_id: 2, maybe_get_id: 1, maybe: 2, map_key_replace: 3]

  @repo Application.get_env(:bonfire_valueflows, :repo_module)

  # alias Bonfire.GraphQL
  alias Bonfire.GraphQL.{Fields, Page}

  @user Application.get_env(:bonfire_valueflows, :user_schema)

  alias ValueFlows.Observation.EconomicResource
  alias ValueFlows.Observation.EconomicResource.Queries
  alias ValueFlows.Observation.EconomicEvent.EconomicEvents

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  @doc """
  Retrieves a single one by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def one(filters), do: @repo.single(Queries.query(EconomicResource, filters))

  @doc """
  Retrieves a list of them by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def many(filters \\ []), do: {:ok, @repo.all(Queries.query(EconomicResource, filters))}

  def fields(group_fn, filters \\ [])
      when is_function(group_fn, 1) do
    {:ok, fields} = many(filters)
    {:ok, Fields.new(fields, group_fn)}
  end

  @doc """
  Retrieves an Page of resources according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(EconomicResource, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- @repo.transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of resources according to various filters

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
      EconomicResource,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end

  def track(%{id: id}) do
    track(id)
  end

  def track(id) when is_binary(id) do
    EconomicEvents.many([:default, track_resource: id])
  end

  def trace(%{id: id}) do
    trace(id)
  end

  def trace(id) when is_binary(id) do
    EconomicEvents.many([:default, trace_resource: id])
  end

  def preload_all(resource) do
    {:ok, resource} = one(id: resource.id, preload: :all)
    preload_state(resource)
  end

  def preload_state(resource) do
    resource |> Map.put(:state, ValueFlows.Knowledge.Action.Actions.action!(resource.state_id))
  end

  ## mutations

  # @spec create(any(), attrs :: map) :: {:ok, EconomicResource.t()} | {:error, Changeset.t()}
  def create(%{} = creator, attrs) when is_map(attrs) do
    @repo.transact_with(fn ->
      attrs = prepare_attrs(attrs, creator)

      with {:ok, resource} <- @repo.insert(EconomicResource.create_changeset(creator, attrs)),
           {:ok, resource} <- ValueFlows.Util.try_tag_thing(creator, resource, attrs),
           act_attrs = %{verb: "created", is_local: true},
           # FIXME
           {:ok, activity} <- ValueFlows.Util.activity_create(creator, resource, act_attrs),
           :ok <- ValueFlows.Util.publish(creator, resource, activity, :created) do
        resource = %{resource | creator: creator}
        resource = preload_all(resource)

        indexing_object_format(resource) |> ValueFlows.Util.index_for_search()
        {:ok, resource}
      end
    end)
  end

  # TODO: take the user who is performing the update
  # @spec update(%EconomicResource{}, attrs :: map) :: {:ok, EconomicResource.t()} | {:error, Changeset.t()}
  def update(%EconomicResource{} = resource, attrs) do
    @repo.transact_with(fn ->
      attrs = prepare_attrs(attrs)

      with {:ok, resource} <- @repo.update(EconomicResource.update_changeset(resource, attrs)),
           {:ok, resource} <- ValueFlows.Util.try_tag_thing(nil, resource, attrs),
           :ok <- ValueFlows.Util.publish(resource, :updated) do
        {:ok, preload_all(resource)}
      end
    end)
  end

  def soft_delete(%EconomicResource{} = resource) do
    @repo.transact_with(fn ->
      with {:ok, resource} <- Bonfire.Repo.Delete.soft_delete(resource),
           :ok <- ValueFlows.Util.publish(resource, :deleted) do
        {:ok, resource}
      end
    end)
  end

  def indexing_object_format(obj) do
    # icon = CommonsPub.Uploads.remote_url_from_id(obj.icon_id)
    image = CommonsPub.Uploads.remote_url_from_id(obj.image_id)

    %{
      "index_type" => "EconomicResource",
      "id" => obj.id,
      # "canonicalUrl" => obj.canonical_url,
      # "icon" => icon,
      "image" => image,
      "name" => obj.name,
      "summary" => Map.get(obj, :note),
      "published_at" => obj.published_at,
      "creator" => ValueFlows.Util.indexing_format_creator(obj)
      # "index_instance" => URI.parse(obj.canonical_url).host, # home instance of object
    }
  end


  defp prepare_attrs(attrs, creator \\ nil) do
    attrs
    |> maybe_put(:primary_accountable_id, attr_get_id(attrs, :primary_accountable) || maybe_get_id(creator))
    |> maybe_put(:context_id,
      attrs |> Map.get(:in_scope_of) |> maybe(&List.first/1)
    )
    |> maybe_put(:current_location_id, attr_get_id(attrs, :current_location))
    |> maybe_put(:conforms_to_id, attr_get_id(attrs, :conforms_to))
    |> maybe_put(:contained_in_id, attr_get_id(attrs, :contained_in))
    |> maybe_put(:unit_of_effort_id, attr_get_id(attrs, :unit_of_effort))
    |> maybe_put(:state_id, attr_get_id(attrs, :state))
    |> parse_measurement_attrs()
  end

  defp parse_measurement_attrs(attrs) do
    for {k, v} <- attrs, into: %{} do
      v =
        if is_map(v) and Map.has_key?(v, :has_unit) do
          map_key_replace(v, :has_unit, :unit_id)
        else
          v
        end

      {k, v}
    end
  end
end
