# SPDX-License-Identifier: AGPL-3.0-only
if Code.ensure_loaded?(Bonfire.API.GraphQL) do
defmodule ValueFlows.Knowledge.ProcessSpecification.GraphQL do

  import Where

  import Bonfire.Common.Config, only: [repo: 0]
  alias ValueFlows.Util

  alias Bonfire.API.GraphQL
  alias Bonfire.API.GraphQL.{
    ResolveField,
    ResolvePages,
    ResolveRootPage,
    FetchPage
  }

  alias ValueFlows.Knowledge.ProcessSpecification
  alias ValueFlows.Knowledge.ProcessSpecification.ProcessSpecifications
  alias ValueFlows.Knowledge.ProcessSpecification.Queries

  ## resolvers

  def simulate(%{id: _id}, _) do
    {:ok, ValueFlows.Simulate.process_specification/0}
  end

  def simulate(_, _) do
    {:ok, Bonfire.Common.Simulation.some(1..5, &ValueFlows.Simulate.process_specification/0)}
  end

  def process_spec(%{id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_process_spec,
      context: id,
      info: info
    })
  end

  def process_specs(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_process_specs,
      page_opts: page_opts,
      info: info,
      # popularity
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Pointers.ULID.cast/1]
    })
  end

  def all_process_specs(_, _) do
    ProcessSpecifications.many()
  end

  def process_specs_filtered(page_opts, _) do
    process_specs_filter(page_opts, [])
  end

  # TODO: support several filters combined, plus pagination on filtered queries

  defp process_specs_filter(%{in_scope_of: context_id} = page_opts, filters_acc) do
    process_specs_filter_next(:in_scope_of, [context_id: context_id], page_opts, filters_acc)
  end

  defp process_specs_filter(%{tag_ids: tag_ids} = page_opts, filters_acc) do
    process_specs_filter_next(:tag_ids, [tag_ids: tag_ids], page_opts, filters_acc)
  end

  defp process_specs_filter(
         _,
         filters_acc
       ) do
    # finally, if there's no more known params to acumulate, query with the filters
    ProcessSpecifications.many(filters_acc)
  end

  defp process_specs_filter_next(param_remove, filter_add, page_opts, filters_acc)
       when is_list(param_remove) and is_list(filter_add) do
    process_specs_filter(Map.drop(page_opts, param_remove), filters_acc ++ filter_add)
  end

  defp process_specs_filter_next(param_remove, filter_add, page_opts, filters_acc)
       when not is_list(filter_add) do
    process_specs_filter_next(param_remove, [filter_add], page_opts, filters_acc)
  end

  defp process_specs_filter_next(param_remove, filter_add, page_opts, filters_acc)
       when not is_list(param_remove) do
    process_specs_filter_next([param_remove], filter_add, page_opts, filters_acc)
  end

  ## fetchers

  def fetch_process_spec(info, id) do
    ProcessSpecifications.one([
      :default,
      user: GraphQL.current_user(info),
      id: id
      # preload: :tags
    ])
  end

  def creator_process_specs_edge(%{creator: creator}, %{} = page_opts, info) do
    ResolvePages.run(%ResolvePages{
      module: __MODULE__,
      fetcher: :fetch_creator_process_specs_edge,
      context: creator,
      page_opts: page_opts,
      info: info
    })
  end

  def fetch_creator_process_specs_edge(page_opts, info, ids) do
    list_process_specs(
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

  def list_process_specs(page_opts, base_filters, _data_filters, _cursor_type) do
    FetchPage.run(%FetchPage{
      queries: Queries,
      query: ProcessSpecification,
      # cursor_fn: ProcessSpecifications.cursor(cursor_type),
      page_opts: page_opts,
      base_filters: base_filters
      # data_filters: data_filters
    })
  end

  def fetch_process_specs(page_opts, info) do
    FetchPage.run(%FetchPage{
      queries: ValueFlows.Knowledge.ProcessSpecification.Queries,
      query: ValueFlows.Knowledge.ProcessSpecification,
      # preload: [:provider, :receiver, :tags],
      # cursor_fn: ProcessSpecifications.cursor(:followers),
      page_opts: page_opts,
      base_filters: [
        :default,
        # preload: [:provider, :receiver, :tags],
        user: GraphQL.current_user(info)
      ]
      # data_filters: [page: [desc: [followers: page_opts]]],
    })
  end

  def create_process_spec(%{process_specification: process_spec_attrs}, info) do
    repo().transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, uploads} <- ValueFlows.Util.GraphQL.maybe_upload(user, process_spec_attrs, info),
           process_spec_attrs = Map.merge(process_spec_attrs, uploads),
           process_spec_attrs = Map.merge(process_spec_attrs, %{is_public: true}),
           {:ok, process_spec} <- ProcessSpecifications.create(user, process_spec_attrs) do
        {:ok, %{process_specification: process_spec}}
      end
    end)
  end

  def update_process_spec(%{process_specification: %{id: id} = changes}, info) do
    repo().transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
          {:ok, process_spec} <- process_spec(%{id: id}, info),
          :ok <- ValueFlows.Util.ensure_edit_permission(user, process_spec),
          {:ok, uploads} <- ValueFlows.Util.GraphQL.maybe_upload(user, changes, info),
          changes = Map.merge(changes, uploads),
          {:ok, process_spec} <- ProcessSpecifications.update(process_spec, changes) do
        {:ok, %{process_specification: process_spec}}
      end
    end)
  end

  def delete_process_spec(%{id: id}, info) do
    repo().transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, process_spec} <- process_spec(%{id: id}, info),
           :ok <- ValueFlows.Util.ensure_edit_permission(user, process_spec),
           {:ok, _} <- ProcessSpecifications.soft_delete(process_spec) do
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
