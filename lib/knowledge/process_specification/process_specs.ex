# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Knowledge.ProcessSpecification.ProcessSpecifications do
  use Bonfire.Common.Utils, only: [maybe: 2, maybe_put: 3]

  import Bonfire.Common.Config, only: [repo: 0]

  # alias Bonfire.API.GraphQL
  alias Bonfire.API.GraphQL.{Fields, Page}

  alias ValueFlows.Knowledge.ProcessSpecification
  alias ValueFlows.Knowledge.ProcessSpecification.Queries

  def federation_module, do: ["ValueFlows:ProcessSpecification", "ProcessSpecification"]

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  @doc """
  Retrieves a single one by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def one(filters), do: repo().single(Queries.query(ProcessSpecification, filters))

  @doc """
  Retrieves a list of them by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def many(filters \\ []), do: {:ok, repo().many(Queries.query(ProcessSpecification, filters))}

  def fields(group_fn, filters \\ [])
      when is_function(group_fn, 1) do
    {:ok, fields} = many(filters)
    {:ok, Fields.new(fields, group_fn)}
  end

  @doc """
  Retrieves an Page of process_specs according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(ProcessSpecification, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- repo().transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of process_specs according to various filters

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
    Bonfire.API.GraphQL.Pagination.pages(
      Queries,
      ProcessSpecification,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end

  ## mutations

  @spec create(any(), attrs :: map) :: {:ok, ProcessSpecification.t()} | {:error, Changeset.t()}
  def create(%{} = creator, attrs) when is_map(attrs) do
    repo().transact_with(fn ->
      attrs = prepare_attrs(attrs)

      with {:ok, item} <- repo().insert(ProcessSpecification.create_changeset(creator, attrs)),
           item <- %{item | creator: creator},
           {:ok, item} <- ValueFlows.Util.try_tag_thing(creator, item, attrs),
           {:ok, activity} <- ValueFlows.Util.publish(creator, :define, item) do

        indexing_object_format(item) |> ValueFlows.Util.index_for_search()

        {:ok, item}
      end
    end)
  end


  # TODO: take the user who is performing the update
  # @spec update(%ProcessSpecification{}, attrs :: map) :: {:ok, ProcessSpecification.t()} | {:error, Changeset.t()}
  def update(%ProcessSpecification{} = process_spec, attrs) do
    repo().transact_with(fn ->
      attrs = prepare_attrs(attrs)

      with {:ok, process_spec} <- repo().update(ProcessSpecification.update_changeset(process_spec, attrs)),
           {:ok, process_spec} <- ValueFlows.Util.try_tag_thing(nil, process_spec, attrs),
           {:ok, _} <- ValueFlows.Util.publish(process_spec, :update) do
        {:ok, process_spec}
      end
    end)
  end

  def soft_delete(%ProcessSpecification{} = process_spec) do
    repo().transact_with(fn ->
      with {:ok, process_spec} <- Bonfire.Common.Repo.Delete.soft_delete(process_spec),
           {:ok, _} <- ValueFlows.Util.publish(process_spec, :deleted) do
        {:ok, process_spec}
      end
    end)
  end

  def indexing_object_format(obj) do

    # image = ValueFlows.Util.image_url(obj)

    %{
      "index_type" => "ValueFlows.ProcessSpecification",
      "id" => obj.id,
      # "url" => obj.character.canonical_url,
      # "icon" => icon,
      # "image" => image,
      "name" => obj.name,
      "summary" => Map.get(obj, :note),
      "published_at" => obj.published_at,
      "creator" => ValueFlows.Util.indexing_format_creator(obj)
      # "index_instance" => URI.parse(obj.character.canonical_url).host, # home instance of object
    }
  end

  def ap_publish_activity(activity_name, thing) do
    ValueFlows.Util.Federation.ap_publish_activity(activity_name, :process_specification, thing, 3, [
      :published_in
    ])
  end

  def ap_receive_activity(creator, activity, object) do
    ValueFlows.Util.Federation.ap_receive_activity(creator, activity, object, &create/2)
  end

  defp prepare_attrs(attrs) do
    attrs
    |> maybe_put(:context_id,
      attrs |> Map.get(:in_scope_of) |> maybe(&List.first/1)
    )
  end
end
