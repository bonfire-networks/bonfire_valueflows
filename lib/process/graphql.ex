# SPDX-License-Identifier: AGPL-3.0-only
if Code.ensure_loaded?(Bonfire.API.GraphQL) do
defmodule ValueFlows.Process.GraphQL do
  import Where

  import Bonfire.Common.Config, only: [repo: 0]
  # TODO: don't use this
  use Bonfire.Common.Utils, only: [map_key_replace_existing: 3, map_key_replace_existing: 4]

  alias Bonfire.API.GraphQL
  alias Bonfire.API.GraphQL.{
    ResolveField,
    # ResolveFields,
    # ResolvePage,
    ResolvePages,
    ResolveRootPage,
    FetchPage
    # FetchPages,
    # CommonResolver
  }

  # alias Bonfire.Common.Enums
  # alias Bonfire.Common.Pointers

  alias ValueFlows.Util
  alias ValueFlows.Process
  alias ValueFlows.Process.Processes
  alias ValueFlows.Process.Queries
  # alias Bonfire.API.GraphQL.CommonResolver

  # SDL schema import
  #  use Absinthe.Schema.Notation
  # import_sdl path: "lib/value_flows/graphql/schemas/planning.gql"

  ## resolvers

  def simulate(%{id: _id}, _) do
    {:ok, ValueFlows.Simulate.process()}
  end

  def simulate(_, _) do
    {:ok, Bonfire.Common.Simulation.some(1..5, &ValueFlows.Simulate.process/0)}
  end

  def process(%{id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_process,
      context: id,
      info: info
    })
  end

  def processes(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_processes,
      page_opts: page_opts,
      info: info,
      # popularity
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Pointers.ULID.cast/1]
    })
  end

  def all_processes(_, _) do
    Processes.many([:default])
  end

  def track(process, attrs, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_track_process,
      context: {process, attrs},
      info: info
    })
  end

  def trace(process, attrs, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_trace_process,
      context: {process, attrs},
      info: info
    })
  end

  def processes_filtered(page_opts, _ \\ nil) do
    #IO.inspect(processes_filtered: page_opts)
    processes_filter(page_opts, [])
  end

  # def processes_filtered(page_opts, _) do
  #   IO.inspect(unhandled_filtering: page_opts)
  #   all_processes(page_opts, nil)
  # end

  # TODO: support several filters combined, plus pagination on filtered queries

  defp processes_filter(%{agent: id} = page_opts, filters_acc) do
    processes_filter_next(:agent, [agent_id: id], page_opts, filters_acc)
  end

  defp processes_filter(%{in_scope_of: context_id} = page_opts, filters_acc) do
    processes_filter_next(:in_scope_of, [context_id: context_id], page_opts, filters_acc)
  end

  defp processes_filter(%{tag_ids: tag_ids} = page_opts, filters_acc) do
    processes_filter_next(:tag_ids, [tag_ids: tag_ids], page_opts, filters_acc)
  end

  defp processes_filter(
         _,
         filters_acc
       ) do
    #IO.inspect(filters_query: filters_acc)

    # finally, if there's no more known params to acumulate, query with the filters
    Processes.many(filters_acc)
  end

  defp processes_filter_next(param_remove, filter_add, page_opts, filters_acc)
       when is_list(param_remove) and is_list(filter_add) do
    #IO.inspect(processes_filter_next: param_remove)
    #IO.inspect(processes_filter_add: filter_add)

    processes_filter(Map.drop(page_opts, param_remove), filters_acc ++ filter_add)
  end

  defp processes_filter_next(param_remove, filter_add, page_opts, filters_acc)
       when not is_list(filter_add) do
    processes_filter_next(param_remove, [filter_add], page_opts, filters_acc)
  end

  defp processes_filter_next(param_remove, filter_add, page_opts, filters_acc)
       when not is_list(param_remove) do
    processes_filter_next([param_remove], filter_add, page_opts, filters_acc)
  end


  def fetch_track_process(_, {process, attrs}) do
    Processes.track(process, Map.get(attrs, :recurse_limit))
  end

  def fetch_track_process(_, process) do
    Processes.track(process)
  end


  def fetch_trace_process(_, {process, attrs}) do
    Processes.trace(process, Map.get(attrs, :recurse_limit))
  end

  def fetch_trace_process(_, process) do
    Processes.trace(process)
  end

  def intended_inputs(process, %{filter: search_params}, _) do
    Processes.intended_inputs(process, parse_search_params(search_params))
  end

  def intended_inputs(process, %{action: action_id}, _) when is_binary(action_id) do
    Processes.intended_inputs(process, action_id: action_id)
  end

  def intended_inputs(process, %{}, info) do
    Processes.intended_inputs(process)
  end

  def intended_outputs(process, %{filter: search_params}, _) do
    Processes.intended_outputs(process, parse_search_params(search_params))
  end

  def intended_outputs(process, %{action: action_id}, _) when is_binary(action_id) do
    Processes.intended_outputs(process, action_id: action_id)
  end

  def intended_outputs(process, %{} = params, info) do
    Processes.intended_outputs(process)
  end

  defp parse_search_params(search_params) do
    search_params
    |> map_key_replace_existing(:action, :action_id)
    |> map_key_replace_existing(:provider, :provider_id)
    |> map_key_replace_existing(:receiver, :receiver_id)
    |> map_key_replace_existing(:search_string, :search)
    |> map_key_replace_existing(:classified_as, :tag_ids, Util.maybe_classification(nil, Map.get(search_params, :classified_as)) |> Enum.map(& (&1.id)))
    |> Keyword.new()
    |> IO.inspect
  end

  def inputs(process, %{action: action_id}, _) when is_binary(action_id) do
    Processes.inputs(process, action_id)
  end

  def inputs(process, _, _) do
    Processes.inputs(process)
  end

  def outputs(process, %{action: action_id}, _) when is_binary(action_id) do
    Processes.outputs(process, action_id)
  end

  def outputs(process, _, _) do
    Processes.outputs(process)
  end


  ## fetchers

  def fetch_process(info, id) do
    Processes.one([
      :default,
      user: GraphQL.current_user(info),
      id: id
      # preload: :tags
    ])
  end

  def creator_processes(%{id: creator}, _page_opts, _info) do
    processes_filtered(%{agent: creator})
  end

  def creator_processes(_, _page_opts, _info) do
    {:ok, nil}
  end

  def creator_processes_edge(%{creator: creator}, %{} = page_opts, info) do
    ResolvePages.run(%ResolvePages{
      module: __MODULE__,
      fetcher: :fetch_creator_processes_edge,
      context: creator,
      page_opts: page_opts,
      info: info
    })
  end

  def fetch_creator_processes_edge(page_opts, info, ids) do
    list_processes(
      page_opts,
      [
        :default,
        agent_id: ids,
        user: GraphQL.current_user(info)
      ],
      nil,
      nil
    )
  end

  def fetch_based_on_edge(%{based_on_id: id} = thing, _, _)
      when is_binary(id) do
    thing = repo().preload(thing, :based_on)
    {:ok, Map.get(thing, :based_on)}
  end

  def fetch_based_on_edge(_, _, _) do
    {:ok, nil}
  end

  def list_processes(page_opts, base_filters, _data_filters, _cursor_type) do
    FetchPage.run(%FetchPage{
      queries: Queries,
      query: Process,
      # cursor_fn: Processes.cursor(cursor_type),
      page_opts: page_opts,
      base_filters: base_filters
      # data_filters: data_filters
    })
  end

  def fetch_processes(page_opts, info) do
    FetchPage.run(%FetchPage{
      queries: ValueFlows.Process.Queries,
      query: ValueFlows.Process,
      # preload: [:provider, :receiver, :tags],
      # cursor_fn: Processes.cursor(:followers),
      page_opts: page_opts,
      cursor_fn: & &1.id,
      base_filters: [
        :default,
        # preload: [:provider, :receiver, :tags],
        user: GraphQL.current_user(info)
      ],
      data_filters: ValueFlows.Util.GraphQL.fetch_data_filters([paginate_id: page_opts], info),
    })
  end

  def create_process(%{process: process_attrs}, info) do
    repo().transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, uploads} <- ValueFlows.Util.GraphQL.maybe_upload(user, process_attrs, info),
           process_attrs = Map.merge(process_attrs, uploads),
           process_attrs = Map.merge(process_attrs, %{is_public: true}),
           {:ok, process} <- Processes.create(user, process_attrs) do
        {:ok, %{process: process}}
      end
    end)
  end

  def update_process(%{process: %{id: id} = changes}, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
         {:ok, process} <- process(%{id: id}, info),
         :ok <- ValueFlows.Util.ensure_edit_permission(user, process),
         {:ok, uploads} <- ValueFlows.Util.GraphQL.maybe_upload(user, changes, info),
         changes = Map.merge(changes, uploads),
         {:ok, process} <- Processes.update(process, changes) do
      {:ok, %{process: process}}
    end
  end

  def delete_process(%{id: id}, info) do
    repo().transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, process} <- process(%{id: id}, info),
           :ok <- ValueFlows.Util.ensure_edit_permission(user, process),
           {:ok, _} <- Processes.soft_delete(process) do
        {:ok, true}
      end
    end)
  end


  # defp validate_agent(pointer) do
  #   if Pointers.table!(pointer).schema in valid_contexts() do
  #     :ok
  #   else
  #     GraphQL.not_permitted()
  #   end
  # end

  # defp valid_contexts() do
  #   [User, Community, Organisation]
  #   # Keyword.fetch!(Bonfire.Common.Config.get(Threads), :valid_contexts)
  # end
end
end
