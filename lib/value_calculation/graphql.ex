# SPDX-License-Identifier: AGPL-3.0-only
if Code.ensure_loaded?(Bonfire.API.GraphQL) do
defmodule ValueFlows.ValueCalculation.GraphQL do
  import Bonfire.Common.Config, only: [repo: 0]

  alias Bonfire.API.GraphQL
  alias Bonfire.API.GraphQL.{FetchPage, ResolveField, ResolveRootPage}
  alias ValueFlows.ValueCalculation.ValueCalculations

  def value_calculation(%{id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_value_calculation,
      context: id,
      info: info
    })
  end

  def value_calculations(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_value_calculations,
      page_opts: page_opts,
      info: info,
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Pointers.ULID.cast/1]
    })
  end

  def fetch_value_calculation(info, id) do
    ValueCalculations.one([
      :default,
      id: id,
      creator: GraphQL.current_user(info)
    ])
  end

  def fetch_value_calculations(page_opts, info) do
    filters = info |> Map.get(:data_filters, %{}) |> Keyword.new()

    FetchPage.run(%FetchPage{
      queries: ValueFlows.ValueCalculation.Queries,
      query: ValueFlows.ValueCalculation,
      page_opts: page_opts,
      cursor_fn: & &1.id,
      base_filters: [
        :default,
        creator: GraphQL.current_user(info)
      ],
      data_filters: [filters ++ [paginate_id: page_opts]],
    })
  end

  def value_action_edge(thing, opts, info) do
    thing
    |> Bonfire.Common.Utils.map_key_replace(:value_action_id, :action_id)
    |> ValueFlows.Knowledge.Action.GraphQL.action_edge(opts, info)
  end

  def value_unit_edge(%{value_unit_id: id} = thing, _, _) when is_binary(id) do
    thing = repo().preload(thing, :value_unit)
    {:ok, Map.get(thing, :value_unit)}
  end

  def value_unit_edge(_, _, _) do
    {:ok, nil}
  end

  def resource_conforms_to_edge(%{resource_conforms_to_id: id} = thing, _, _) when is_binary(id) do
    thing = repo().preload(thing, :resource_conforms_to)
    {:ok, Map.get(thing, :resource_conforms_to)}
  end

  def resource_conforms_to_edge(_, _, _) do
    {:ok, nil}
  end

  def value_resource_conforms_to_edge(%{value_resource_conforms_to_id: id} = thing, _, _) when is_binary(id) do
    thing = repo().preload(thing, :value_resource_conforms_to)
    {:ok, Map.get(thing, :value_resource_conforms_to)}
  end

  def value_resource_conforms_to_edge(_, _, _) do
    {:ok, nil}
  end

  def create_value_calculation(%{value_calculation: attrs}, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
         {:ok, value_calculation} <- ValueCalculations.create(user, attrs) do
      {:ok, %{value_calculation: value_calculation}}
    end
  end

  def update_value_calculation(%{value_calculation: %{id: id} = attrs}, info) do
    with :ok <- GraphQL.is_authenticated(info),
         {:ok, value_calculation} <- value_calculation(%{id: id}, info),
         {:ok, value_calculation} <- ValueCalculations.update(value_calculation, attrs) do
      {:ok, %{value_calculation: value_calculation}}
    end
  end

  def delete_value_calculation(%{id: id}, info) do
    with :ok <- GraphQL.is_authenticated(info),
         {:ok, value_calculation} <- value_calculation(%{id: id}, info),
         {:ok, _} <- ValueCalculations.soft_delete(value_calculation) do
      {:ok, true}
    end
  end
end
end
