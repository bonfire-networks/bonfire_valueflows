# SPDX-License-Identifier: AGPL-3.0-only
if Code.ensure_loaded?(Bonfire.GraphQL) do
defmodule ValueFlows.Planning.Intent.GraphQL do
  # default to 100 km radius
  @radius_default_distance 100_000

  require Logger

  alias Bonfire.Common.Utils
  import Bonfire.Common.Config, only: [repo: 0]
  alias ValueFlows.Util

  alias Bonfire.GraphQL
  alias Bonfire.GraphQL.{
    ResolveField,
    ResolvePages,
    ResolveRootPage,
    FetchPage
  }

  alias ValueFlows.Planning.Intent
  alias ValueFlows.Planning.Intent.Intents
  alias ValueFlows.Planning.Intent.Queries
  alias ValueFlows.Planning.Satisfaction.Satisfactions

  ## resolvers

  def intent(%{id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_intent,
      context: id,
      info: info
    })
  end

  def intents(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_intents,
      page_opts: page_opts,
      info: info,
      # popularity
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Pointers.ULID.cast/1]
    })
  end


  def intents_filtered(%{filter: filters} = args, info) when is_map(filters) and filters != %{} do
    intents_filter(filters, [limit: Map.get(args, :limit, 10), offset: Map.get(args, :start, 0)], GraphQL.current_user(info))
  end

  def intents_filtered(args, _) do
    Intents.many([:default, limit: Map.get(args, :limit, 10), offset: Map.get(args, :start, 0)])
  end


  # TODO: pagination on filtered queries

  defp intents_filter(page_opts, filters_acc, current_user \\ nil)

  defp intents_filter(%{agent: id} = page_opts, filters_acc, current_user) do
    intents_filter_next(:agent, [agent_id: id_or_me(id, current_user)], page_opts, filters_acc, current_user)
  end

  defp intents_filter(%{provider: id} = page_opts, filters_acc, current_user) do
    intents_filter_next(:provider, [provider_id: id_or_me(id, current_user)], page_opts, filters_acc, current_user)
  end

  defp intents_filter(%{receiver: id} = page_opts, filters_acc, current_user) do
    intents_filter_next(:receiver, [receiver_id: id_or_me(id, current_user)], page_opts, filters_acc, current_user)
  end

  defp intents_filter(%{action: id} = page_opts, filters_acc, current_user) do
    intents_filter_next(:action, [action_id: id], page_opts, filters_acc, current_user)
  end

  defp intents_filter(%{status: status} = page_opts, filters_acc, current_user) do
    intents_filter_next(:status, [status: status], page_opts, filters_acc, current_user)
  end

  defp intents_filter(%{finished: true} = page_opts, filters_acc, current_user) do
    intents_filter_next(:finished, [status: :closed], page_opts, filters_acc, current_user)
  end

  defp intents_filter(%{finished: false} = page_opts, filters_acc, current_user) do
    intents_filter_next(:finished, [status: :open], page_opts, filters_acc, current_user)
  end

  defp intents_filter(%{in_scope_of: context_id} = page_opts, filters_acc, current_user) do
    intents_filter_next(:in_scope_of, [context_id: context_id], page_opts, filters_acc, current_user)
  end

  defp intents_filter(%{tag_ids: tag_ids} = page_opts, filters_acc, current_user) do
    intents_filter_next(:tag_ids, [tag_ids: tag_ids], page_opts, filters_acc, current_user)
  end

  defp intents_filter(%{classified_as: tags} = page_opts, filters_acc, current_user) do
    intents_filter_next(:classified_as, [tag_ids: Util.maybe_classification(current_user, tags) |> Enum.map(& (&1.id))], page_opts, filters_acc, current_user)
  end

  defp intents_filter(%{at_location: at_location_id} = page_opts, filters_acc, current_user) do
    intents_filter_next(:at_location, [at_location_id: at_location_id], page_opts, filters_acc, current_user)
  end

  defp intents_filter(%{start_date: date} = page_opts, filters_acc, current_user) do
    intents_filter_next(:start_date, [start_date: date], page_opts, filters_acc, current_user)
  end

  defp intents_filter(%{end_date: date} = page_opts, filters_acc, current_user) do
    intents_filter_next(:end_date, [end_date: date], page_opts, filters_acc, current_user)
  end

  defp intents_filter(
         %{
           geolocation: %{
             near_point: %{lat: lat, long: long},
             distance: %{meters: distance_meters}
           }
         } = page_opts,
         filters_acc, current_user
       ) do
    intents_filter_next(
      :geolocation,
      {
        :near_point,
        %Geo.Point{coordinates: {lat, long}, srid: 4326},
        :distance_meters,
        distance_meters
      },
      page_opts,
      filters_acc, current_user
    )
  end

  defp intents_filter(
         %{
           geolocation: %{near_address: address} = geolocation
         } = page_opts,
         filters_acc, current_user
       ) do
    with {:ok, coords} <- Geocoder.call(address) do

      intents_filter(
        Map.merge(
          page_opts,
          %{
            geolocation:
              Map.merge(geolocation, %{
                near_point: %{lat: coords.lat, long: coords.lon},
                distance: Map.get(geolocation, :distance, %{meters: @radius_default_distance})
              })
          }
        ),
        filters_acc, current_user
      )
    else
      _ ->
        intents_filter_next(
          :geolocation,
          [],
          page_opts,
          filters_acc, current_user
        )
    end
  end

  defp intents_filter(
         %{
           geolocation: geolocation
         } = page_opts,
         filters_acc, current_user
       ) do
    intents_filter(
      Map.merge(
        page_opts,
        %{
          geolocation:
            Map.merge(geolocation, %{
              # default to 100 km radius
              distance: %{meters: @radius_default_distance}
            })
        }
      ),
      filters_acc, current_user
    )
  end

  defp intents_filter(
         _,
         filters_acc, current_user
       ) do
    # finally, if there's no more known params to acumulate, query with the filters
    Intents.many([:default] ++ filters_acc)
  end

  defp intents_filter_next(param_remove, filter_add, page_opts, filters_acc, current_user)
       when is_list(param_remove) and is_list(filter_add) do
    intents_filter(Map.drop(page_opts, param_remove), filters_acc ++ filter_add, current_user)
  end

  defp intents_filter_next(param_remove, filter_add, page_opts, filters_acc, current_user)
       when not is_list(filter_add) do
    intents_filter_next(param_remove, [filter_add], page_opts, filters_acc, current_user)
  end

  defp intents_filter_next(param_remove, filter_add, page_opts, filters_acc, current_user)
       when not is_list(param_remove) do
    intents_filter_next([param_remove], filter_add, page_opts, filters_acc, current_user)
  end

  defp id_or_me(["me"], current_user), do: Utils.maybe_get(current_user, :id) || raise "You need to be logged in for this"
  defp id_or_me(id, _), do: id


  def offers(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_offers,
      page_opts: page_opts,
      info: info,
      # popularity
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Pointers.ULID.cast/1]
    })
  end

  def needs(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_needs,
      page_opts: page_opts,
      info: info,
      # popularity
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Pointers.ULID.cast/1]
    })
  end

  ## fetchers

  def fetch_intent(info, id) do
    Intents.by_id(id, GraphQL.current_user(info))
  end

  def agent_intents(%{id: agent}, %{} = _page_opts, info) do
    intents_filtered(%{agent: agent}, info)
  end

  def agent_intents(_, _page_opts, _info) do
    {:ok, nil}
  end

  def provider_intents(%{id: provider}, %{} = _page_opts, info) do
    intents_filtered(%{provider: provider}, info)
  end

  def provider_intents(_, _page_opts, _info) do
    {:ok, nil}
  end

  def agent_intents_edge(%{id: agent}, %{} = page_opts, info) do
    ResolvePages.run(%ResolvePages{
      module: __MODULE__,
      fetcher: :fetch_agent_intents_edge,
      context: agent,
      page_opts: page_opts,
      info: info
    })
  end

  def fetch_agent_intents_edge(page_opts, info, ids) do
    list_intents(
      page_opts,
      [
        :default,
        agent_id: ids,
        user: GraphQL.current_user(info)
      ]
    )
  end

  def provider_intents_edge(%{id: provider}, %{} = page_opts, info) do
    ResolvePages.run(%ResolvePages{
      module: __MODULE__,
      fetcher: :fetch_provider_intents_edge,
      context: provider,
      page_opts: page_opts,
      info: info
    })
  end

  def fetch_provider_intents_edge(page_opts, info, ids) do
    list_intents(
      page_opts,
      [
        :default,
        provider_id: ids,
        user: GraphQL.current_user(info)
      ]
    )
  end

  def fetch_resource_inventoried_as_edge(%{resource_inventoried_as_id: id} = thing, _, _)
      when is_binary(id) do
    thing = repo().preload(thing, :resource_inventoried_as)
    {:ok, Map.get(thing, :resource_inventoried_as)}
  end

  def fetch_resource_inventoried_as_edge(_, _, _) do
    {:ok, nil}
  end

  def fetch_input_of_edge(%{input_of_id: id} = thing, _, _)
      when is_binary(id) do
    thing = repo().preload(thing, :input_of)
    {:ok, Map.get(thing, :input_of)}
  end

  def fetch_input_of_edge(_, _, _) do
    {:ok, nil}
  end

  def fetch_output_of_edge(%{output_of_id: id} = thing, _, _)
      when is_binary(id) do
    thing = repo().preload(thing, :output_of)
    {:ok, Map.get(thing, :output_of)}
  end

  def fetch_output_of_edge(_, _, _) do
    {:ok, nil}
  end

  def fetch_satisfied_by_edge(%{id: id}, _, _) when is_binary(id),
    do: Satisfactions.many([:default, satisfies_id: id])

  def fetch_satisfied_by_edge(_, _, _),
    do: {:ok, nil}

  def list_intents(page_opts, base_filters) do
    FetchPage.run(%FetchPage{
      queries: Queries,
      query: Intent,
      # cursor_fn: Intents.cursor(cursor_type),
      page_opts: page_opts,
      base_filters: base_filters
      # data_filters: data_filters
    })
  end

  def fetch_intents(page_opts, info) do
    list_intents(
      page_opts,
      [:default, user: GraphQL.current_user(info)]
    )
  end

  def fetch_offers(page_opts, info) do
    list_intents(
      page_opts,
      [:default, :offer, user: GraphQL.current_user(info)]
    )
  end

  def fetch_needs(page_opts, info) do
    list_intents(
      page_opts,
      [:default, :need, user: GraphQL.current_user(info)]
    )
  end

  def create_offer(%{intent: intent_attrs}, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info) do
      create_intent(
        %{intent: Map.put(intent_attrs, :provider, user.id)},
        info
      )
    end
  end

  def create_need(%{intent: intent_attrs}, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info) do
      create_intent(
        %{intent: Map.put(intent_attrs, :receiver, user.id)},
        info
      )
    end
  end

  def create_intent(%{intent: intent_attrs}, info) do
    repo().transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, uploads} <- ValueFlows.Util.GraphQL.maybe_upload(user, intent_attrs, info),
           intent_attrs = Map.merge(intent_attrs, uploads),
           intent_attrs = Map.merge(intent_attrs, %{is_public: true}),
           {:ok, intent} <- Intents.create(user, intent_attrs) do
        {:ok, %{intent: intent}}
      end
    end)
  end

  def update_intent(%{intent: %{id: id} = changes}, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
         {:ok, intent} <- Intents.by_id(id, user),
         :ok <- ValueFlows.Util.ensure_edit_permission(user, intent),
         {:ok, uploads} <- ValueFlows.Util.GraphQL.maybe_upload(user, changes, info),
         changes = Map.merge(changes, uploads),
         {:ok, intent} <- Intents.update(user, intent, changes) do
      {:ok, %{intent: intent}}
    end
  end

  def delete_intent(%{id: id}, info) do
    repo().transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, _} <- Intents.soft_delete(user, id) do
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
