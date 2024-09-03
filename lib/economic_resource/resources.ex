# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.EconomicResource.EconomicResources do
  use Bonfire.Common.Utils,
    only: [
      maybe: 2,
      e: 3
    ]

  import Bonfire.Common.Config, only: [repo: 0]
  alias ValueFlows.Util
  # alias Bonfire.API.GraphQL
  alias Bonfire.API.GraphQL.Fields
  alias Bonfire.API.GraphQL.Page

  alias ValueFlows.EconomicResource
  alias ValueFlows.EconomicResource.Queries
  alias ValueFlows.EconomicEvent.EconomicEvents

  @search_type "ValueFlows.EconomicResource"

  @behaviour Bonfire.Federate.ActivityPub.FederationModules
  def federation_module, do: ["ValueFlows:EconomicResource", "EconomicResource"]

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  @doc """
  Retrieves a single one by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def one(filters), do: repo().single(Queries.query(EconomicResource, filters))

  @doc """
  Retrieves a list of them by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def many(filters \\ []), do: {:ok, many!(filters)}

  def many!(filters \\ []),
    do: repo().many(Queries.query(EconomicResource, filters))

  def search(search) do
    ValueFlows.Util.maybe_search(search, @search_type) ||
      many!(autocomplete: search)
  end

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
  def page(
        cursor_fn,
        page_opts,
        base_filters \\ [],
        data_filters \\ [],
        count_filters \\ []
      )

  def page(
        cursor_fn,
        %{} = page_opts,
        base_filters,
        data_filters,
        count_filters
      ) do
    base_q = Queries.query(EconomicResource, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <-
           repo().transact_many(all: data_q, count: count_q) do
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

  def pages(
        cursor_fn,
        group_fn,
        page_opts,
        base_filters,
        data_filters,
        count_filters
      ) do
    Bonfire.API.GraphQL.Pagination.pages(
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

  def inputs_of(process) when not is_nil(process) do
    many([:default, [join: [event_input: uid(process)]]])
  end

  def outputs_of(process) when not is_nil(process) do
    many([:default, join: [event_output: uid(process)]])
  end

  defdelegate trace(
                event,
                recurse_limit \\ Util.default_recurse_limit(),
                recurse_counter \\ 0
              ),
              to: ValueFlows.EconomicEvent.Trace,
              as: :resource

  defdelegate track(
                event,
                recurse_limit \\ Util.default_recurse_limit(),
                recurse_counter \\ 0
              ),
              to: ValueFlows.EconomicEvent.Track,
              as: :resource

  def preload_all(resource) do
    {:ok, resource} = one(id: resource.id, preload: :all)
    preload_state(resource)
  end

  def preload_state(resource) do
    Map.put(
      resource,
      :state,
      ValueFlows.Knowledge.Action.Actions.action!(resource.state_id)
    )
  end

  ## mutations

  # @spec create(any(), attrs :: map) :: {:ok, EconomicResource.t()} | {:error, Changeset.t()}
  def create(creator, attrs) when is_map(attrs) do
    repo().transact_with(fn ->
      attrs = prepare_attrs(attrs, creator)

      with {:ok, resource} <-
             repo().insert(EconomicResource.create_changeset(creator, attrs)),
           resource <- preload_all(%{resource | creator: creator}),
           {:ok, resource} <-
             ValueFlows.Util.try_tag_thing(creator, resource, attrs) do
        # {:ok, activity} = ValueFlows.Util.publish(creator, resource.state_id, resource, attrs: attrs) # no need to publish since the related event will already appear in feeds
        ValueFlows.Util.prepare_opts_and_maybe_set_boundaries(creator, resource)

        indexing_object_format(resource) |> ValueFlows.Util.index_for_search()

        {:ok, resource}
      end
    end)
  end

  # TODO: take the user who is performing the update
  # @spec update(%EconomicResource{}, attrs :: map) :: {:ok, EconomicResource.t()} | {:error, Changeset.t()}
  def update(%EconomicResource{} = resource, attrs) do
    repo().transact_with(fn ->
      attrs = prepare_attrs(attrs, e(resource, :creator, nil))

      with {:ok, resource} <-
             repo().update(EconomicResource.update_changeset(resource, attrs)),
           {:ok, resource} <-
             ValueFlows.Util.try_tag_thing(nil, resource, attrs) do
        #  {:ok, _} <- ValueFlows.Util.publish(resource, :update) # Do not publish resource update since that's done via Economic Events
        {:ok, preload_all(resource)}
      end
    end)
  end

  def soft_delete(%EconomicResource{} = resource) do
    repo().transact_with(fn ->
      with {:ok, resource} <- Bonfire.Common.Repo.Delete.soft_delete(resource),
           {:ok, _} <- ValueFlows.Util.publish(resource, :deleted) do
        {:ok, resource}
      end
    end)
  end

  def indexing_object_format(obj) do
    image = ValueFlows.Util.image_url(obj)

    %{
      "index_type" => @search_type,
      "id" => obj.id,
      # "url" => obj.canonical_url,
      # "icon" => icon,
      "image" => image,
      "name" => obj.name,
      "summary" => Map.get(obj, :note),
      "published_at" => obj.published_at,
      "creator" => ValueFlows.Util.indexing_format_creator(obj),
      "tags" => ValueFlows.Util.indexing_format_tags(obj)

      # "index_instance" => URI.parse(obj.canonical_url).host, # home instance of object
    }

    # |> IO.inspect
  end

  def ap_publish_activity(subject, activity_name, thing) do
    ValueFlows.Util.Federation.ap_publish_activity(
      subject,
      activity_name,
      :economic_resource,
      thing,
      3,
      []
    )
  end

  def ap_receive_activity(creator, activity, object) do
    ValueFlows.Util.Federation.ap_receive_activity(
      creator,
      activity,
      object,
      &create/2
    )
  end

  defp prepare_attrs(attrs, creator \\ nil) do
    attrs
    |> Enums.maybe_put(
      :primary_accountable_id,
      Enums.attr_get_id(attrs, :primary_accountable) || uid(creator)
    )
    |> Enums.maybe_put(
      :context_id,
      attrs |> Map.get(:in_scope_of) |> maybe(&List.first/1)
    )
    |> Enums.maybe_put(:current_location_id, Enums.attr_get_id(attrs, :current_location))
    |> Enums.maybe_put(:conforms_to_id, Enums.attr_get_id(attrs, :conforms_to))
    |> Enums.maybe_put(:contained_in_id, Enums.attr_get_id(attrs, :contained_in))
    |> Enums.maybe_put(:unit_of_effort_id, Enums.attr_get_id(attrs, :unit_of_effort))
    |> Enums.maybe_put(:state_id, Enums.attr_get_id(attrs, :state))
    |> Util.parse_measurement_attrs(creator)
  end
end
