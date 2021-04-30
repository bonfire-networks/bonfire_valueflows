# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Process.Processes do
  import Bonfire.Common.Utils, only: [maybe_put: 3, attr_get_id: 2, maybe: 2]

  import Bonfire.Common.Config, only: [repo: 0]

  # alias Bonfire.GraphQL
  alias Bonfire.GraphQL.{Fields, Page}

  @user Bonfire.Common.Config.get!(:user_schema)

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
  def many(filters \\ []), do: {:ok, repo().all(Queries.query(Process, filters))}

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

  def track(process), do: outputs(process)

  def trace(process), do: inputs(process)


  def intended_inputs(attrs, action_id \\ nil)
  def intended_inputs(%{id: id}, action_id) when not is_nil(action_id) do
    Intents.many([:default, input_of_id: id, action_id: action_id])
  end

  def intended_inputs(%{id: id}, _) do
    Intents.many([:default, input_of_id: id])
  end

  def intended_inputs(_, _) do
    {:ok, nil}
  end

  def intended_outputs(attrs, action_id \\ nil)
  def intended_outputs(%{id: id}, action_id) when not is_nil(action_id) do
    Intents.many([:default, output_of_id: id, action_id: action_id])
  end

  def intended_outputs(%{id: id}, _) do
    Intents.many([:default, output_of_id: id])
  end

  def intended_outputs(_, _) do
    {:ok, nil}
  end


  def inputs(attrs, action_id \\ nil)
  def inputs(%{id: id}, action_id) when not is_nil(action_id) do
    EconomicEvents.many([:default, input_of_id: id, action_id: action_id])
  end

  def inputs(%{id: id}, _) do
    EconomicEvents.many([:default, input_of_id: id])
  end

  def inputs(_, _) do
    {:ok, nil}
  end

  def outputs(attrs, action_id \\ nil)
  def outputs(%{id: id}, action_id) when not is_nil(action_id) do
    EconomicEvents.many([:default, output_of_id: id, action_id: action_id])
  end

  def outputs(%{id: id}, _) do
    EconomicEvents.many([:default, output_of_id: id])
  end

  def outputs(_, _) do
    {:ok, nil}
  end


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
           {:ok, process} <- ValueFlows.Util.try_tag_thing(creator, process, attrs),
           act_attrs = %{verb: "created", is_local: true},
           # FIXME
           {:ok, activity} <- ValueFlows.Util.activity_create(creator, process, act_attrs),
           :ok <- ValueFlows.Util.publish(creator, process, activity, :created) do
        indexing_object_format(process) |> ValueFlows.Util.index_for_search()
        {:ok, preload_all(process)}
      end
    end)
  end

  # TODO: take the user who is performing the update
  # @spec update(%Process{}, attrs :: map) :: {:ok, Process.t()} | {:error, Changeset.t()}
  def update(%Process{} = process, attrs) do
    repo().transact_with(fn ->
      attrs = prepare_attrs(attrs)

      with {:ok, process} <- repo().update(Process.update_changeset(process, attrs)),
           {:ok, process} <- ValueFlows.Util.try_tag_thing(nil, process, attrs),
           :ok <- ValueFlows.Util.publish(process, :updated) do
        {:ok, preload_all(process)}
      end
    end)
  end

  def soft_delete(%Process{} = process) do
    repo().transact_with(fn ->
      with {:ok, process} <- Bonfire.Repo.Delete.soft_delete(process),
           :ok <- ValueFlows.Util.publish(process, :deleted) do
        {:ok, process}
      end
    end)
  end

  def indexing_object_format(obj) do

    %{
      "index_type" => "Process",
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


  defp prepare_attrs(attrs) do
    attrs
    |> maybe_put(:based_on_id, attr_get_id(attrs, :based_on))
    |> maybe_put(:context_id,
      attrs |> Map.get(:in_scope_of) |> maybe(&List.first/1)
    )
  end
end
