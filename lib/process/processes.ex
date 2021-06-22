# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Process.Processes do
  import Bonfire.Common.Utils, only: [maybe_put: 3, attr_get_id: 2, maybe: 2]

  import Bonfire.Common.Config, only: [repo: 0]

  # alias Bonfire.GraphQL
  alias Bonfire.GraphQL.{Fields, Page}

  alias ValueFlows.Util

  alias ValueFlows.Process
  alias ValueFlows.Process.Queries
  alias ValueFlows.EconomicEvent.EconomicEvents
  alias ValueFlows.Planning.Intent.Intents

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  @doc """
  Retrieves a single one by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def one(filters), do: repo().single(Queries.query(Process, filters))

  @doc """
  Retrieves a list of them by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def many(filters \\ []), do: {:ok, repo().many(Queries.query(Process, filters))}

  def fields(group_fn, filters \\ [])
      when is_function(group_fn, 1) do
    {:ok, fields} = many(filters)
    {:ok, Fields.new(fields, group_fn)}
  end

  @doc """
  Retrieves an Page of processes according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(Process, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- repo().transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of processes according to various filters

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
      Process,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end


  def intended_inputs(%{id: id}, filters \\ []) do
    Intents.many([:default, input_of_id: id] ++ filters)
  end

  def intended_outputs(%{id: id}, filters \\ []) do
    Intents.many([:default, output_of_id: id] ++ filters)
  end

  defdelegate trace(event, recurse_limit \\ Util.default_recurse_limit(), recurse_counter \\ 0), to: ValueFlows.EconomicEvent.Trace, as: :process
  defdelegate track(event, recurse_limit \\ Util.default_recurse_limit(), recurse_counter \\ 0), to: ValueFlows.EconomicEvent.Track, as: :process


  defdelegate inputs(attrs, action_id \\ nil), to: ValueFlows.EconomicEvent.EconomicEvents, as: :inputs_of
  defdelegate outputs(attrs, action_id \\ nil), to: ValueFlows.EconomicEvent.EconomicEvents, as: :outputs_of


  def preload_all(%Process{} = process) do
    # shouldn't fail
    {:ok, process} = one(id: process.id, preload: :all)
    process
  end

  ## mutations

  # @spec create(any(), attrs :: map) :: {:ok, Process.t()} | {:error, Changeset.t()}
  def create(%{} = creator, attrs) when is_map(attrs) do
    repo().transact_with(fn ->
      attrs = prepare_attrs(attrs)

      with {:ok, process} <- repo().insert(Process.create_changeset(creator, attrs)),
           process <- preload_all(process),
           {:ok, process} <- ValueFlows.Util.try_tag_thing(creator, process, attrs),
           {:ok, activity} <- ValueFlows.Util.publish(creator, :create, process) do
        indexing_object_format(process) |> ValueFlows.Util.index_for_search()
        {:ok, process}
      end
    end)
  end

  # TODO: take the user who is performing the update
  # @spec update(%Process{}, attrs :: map) :: {:ok, Process.t()} | {:error, Changeset.t()}
  def update(%Process{} = process, attrs) do
    repo().transact_with(fn ->
      attrs = prepare_attrs(attrs)

      with {:ok, process} <- repo().update(Process.update_changeset(process, attrs)),
           process <- preload_all(process),
           {:ok, process} <- ValueFlows.Util.try_tag_thing(nil, process, attrs),
           {:ok, _} <- ValueFlows.Util.publish(process, :update) do
        {:ok, process}
      end
    end)
  end

  def soft_delete(%Process{} = process) do
    repo().transact_with(fn ->
      with {:ok, process} <- Bonfire.Repo.Delete.soft_delete(process),
           {:ok, _} <- ValueFlows.Util.publish(process, :deleted) do
        {:ok, process}
      end
    end)
  end

  def indexing_object_format(obj) do

    %{
      "index_type" => "ValueFlows.Process",
      "id" => obj.id,
      # "url" => obj.canonical_url,
      # "icon" => icon,
      "name" => obj.name,
      "summary" => Map.get(obj, :note),
      "published_at" => obj.published_at,
      "creator" => ValueFlows.Util.indexing_format_creator(obj)
      # "index_instance" => URI.parse(obj.canonical_url).host, # home instance of object
    }
  end


  def prepare_attrs(attrs) do
    attrs
    |> maybe_put(:based_on_id, attr_get_id(attrs, :based_on))
    |> maybe_put(:context_id,
      attrs |> Map.get(:in_scope_of) |> maybe(&List.first/1)
    )
  end
end
