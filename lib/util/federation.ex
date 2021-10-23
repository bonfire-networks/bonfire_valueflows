defmodule ValueFlows.Util.Federation do
  import Bonfire.Common.Utils
  require Logger

  @log_graphql false

  @schema Bonfire.Common.Config.get!(:graphql_schema_module)
  @all_types Bonfire.Common.Config.get!(:all_types) || []
  @non_prefixed_types @all_types ++ ["Person", "Organization"]

  @fields_to_AP %{
    "__typename" => "type",
    "canonicalUrl" => "id",
    "inScopeOf" => "context",
    "creator" => "actor",
    "displayUsername" => "preferredUsername",
    "created" => "published",
    # "hasBeginning" => "published",
    "note" => "summary",
    "icon" => "image",
    "lat" => "latitude",
    "long" => "longitude",
  }
  @fields_from_AP Map.new(@fields_to_AP, fn {key, val} -> {val, key} end)

  @graphql_ignore_fields [
    :communities,
    :collections,
    :my_like,
    :my_flag,
    :unit_based,
    :feature_count,
    :follower_count,
    :is_local,
    :is_disabled,
    :page_info,
    :edges,
    :threads,
    :outbox,
    :inbox,
    :followers,
    :community_follows,
    :intents,
    :processes,
    :proposals,
    :inventoried_economic_resources,
    :geom, # see https://www.w3.org/TR/activitystreams-core/#extensibility
  ]

  def ap_publish_activity(
        "create" = activity_type,
        schema_type,
        %{id: id} = thing,
        query_depth \\ 2,
        extra_field_filters \\ []
      )
    when is_binary(id) do

    if Bonfire.Common.Utils.module_enabled?(ActivityPub) do

      Logger.info("ValueFlows.Federation - create #{schema_type}")

      with %{} = api_object <- ap_fetch_object(id, schema_type, query_depth, extra_field_filters) |> ap_prepare_object(),
           activity_params <- ap_prepare_activity(
              activity_type,
              thing,
              api_object
            ),
          {:ok, activity} <- ActivityPub.create(activity_params, id) do

        IO.inspect(activity_created: activity)

        # IO.puts(struct_to_json(activity.data))
        # IO.puts(struct_to_json(activity.object.data))

        # if is_map_key(thing, :canonical_url) do
        #   Ecto.Changeset.change(thing, %{canonical_url: activity_object_id(activity)})
        #   |> Bonfire.Repo.update()
        # end

        {:ok, activity}
      else
        e -> {:error, e}
      end
    end
  end

  def ap_fetch_object(id, schema_type, query_depth \\ 2, extra_field_filters \\ []) do
    field_filters = @graphql_ignore_fields ++ extra_field_filters

    Logger.info("ValueFlows.Federation - query all fields except #{inspect field_filters}")

    with obj <-
           Bonfire.GraphQL.QueryHelper.run_query_id(
             id,
             @schema,
             schema_type,
             query_depth,
             &ap_graphql_fields(&1, field_filters),
             @log_graphql
           ) do

      # IO.inspect(obj, label: "queried via API")

      obj
    end

  rescue e ->
    Logger.error(e)
    {:error, e}
  end

  def ap_prepare_object(obj) do
    obj |> to_AP_deep_remap() |> IO.inspect(label: "prepared for federation")
  end

  def ap_prepare_activity("create", thing, object, author_id \\ nil) do

    if Bonfire.Common.Utils.module_enabled?(Bonfire.Federate.ActivityPub.Utils) do

      with context <-
            maybe_get_ap_id_by_local_id(Map.get(object, "context")),
          author <-
            author_id || maybe_id(thing, "creator") || maybe_id(thing, "primary_accountable") ||
              maybe_id(thing, "provider") || maybe_id(thing, "receiver"),
          actor <- Bonfire.Federate.ActivityPub.Utils.get_cached_actor_by_local_id!(author),
          ap_id <- Bonfire.Federate.ActivityPub.Utils.generate_object_ap_id(thing),
          object <-
            Map.merge(object, %{
              "id" => ap_id,
              "actor" => actor.ap_id,
              "attributedTo" => actor.ap_id
            })
            |> maybe_put("context", context),
          activity_params = %{
            actor: actor,
            to: [Bonfire.Federate.ActivityPub.Utils.public_uri(), context] |> Enum.reject(&is_nil/1),
            object: object,
            context: context,
            additional: %{
              "cc" => [actor.data["followers"]]
            }
          } do
        activity_params |> IO.inspect(label: "activity_params")
      end
    else
      Logger.info("VF - No integration available to federate activity")
    end
  end

  def maybe_id(thing, key) do
    e(thing, key, :id, e(thing, key, nil))
  end

  def ap_receive_activity(creator, activity, object, fun) do
    # TODO: target guest circle if activity.public==true
    # TODO: target right circles/boundaries based on to/cc
    IO.inspect(activity: activity)
    # IO.inspect(object: object)
    attrs = e(object, :data, object)
    |> from_AP_deep_remap()
    |> input_to_atoms()
    |> IO.inspect(label: "attrs")

    fun.(creator, attrs)
  end

  defp maybe_get_ap_id_by_local_id("http"<>_ = url) do # TODO better
    url
  end
  defp maybe_get_ap_id_by_local_id(id) when is_binary(id) do
    Bonfire.Federate.ActivityPub.Utils.get_cached_actor_by_local_id!(id) |> e(:ap_id, nil)
  end
  defp maybe_get_ap_id_by_local_id(%{id: id}), do: maybe_get_ap_id_by_local_id(id)
  defp maybe_get_ap_id_by_local_id(%{"id"=> id}), do: maybe_get_ap_id_by_local_id(id)
  defp maybe_get_ap_id_by_local_id(_), do: nil

  def ap_graphql_fields(e, field_filters \\ []) do
    #IO.inspect(e)

    ap_graphql_fields_filter(e, field_filters)
    |> IO.inspect(label: "ap_graphql_fields")
  end


  defp ap_graphql_fields_filter(e, field_filters \\ []) do

    case e do
      {key, {key2, val}} ->
        if key not in field_filters and key2 not in field_filters and
             is_list(val) do
          {key, {key2, for(n <- val, do: ap_graphql_fields_filter(n, field_filters))}}
          # else
          #   IO.inspect(hmm1: e)
        end

      {key, val} ->
        if key not in field_filters and is_list(val) do
          {key, for(n <- val, do: ap_graphql_fields_filter(n, field_filters))}
          # else
          #   IO.inspect(hmm2: e)
        end

      _ ->
        if e not in field_filters, do: e
    end
    # |> IO.inspect(label: "ap_graphql_fields_filter")
  end

  def to_AP_deep_remap(map, parent_key \\ nil)

  def to_AP_deep_remap(map = %{}, parent_key) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) or v == %{} end)
    |> Enum.reject(fn {k, _} -> Enum.member?(@graphql_ignore_fields, maybe_to_snake_atom(k)) end) # FIXME: this shouldn't be necessary if ap_graphql_fields_filter filters them all from the query
    |> Enum.map(fn {k, v} -> to_AP_remap(v, k, map) end)
    |> Enum.into(%{})
  end

  def to_AP_deep_remap(list, parent_key) when is_list(list) do
    list
    |> Enum.reject(fn v -> is_nil(v) or v == %{} end)
    |> Enum.map(fn v -> to_AP_deep_remap(v, parent_key) end)
  end

  def to_AP_deep_remap("SpatialThing", "__typename") do
    # https://www.w3.org/TR/activitystreams-vocabulary/#places
    "Place"
  end

  def to_AP_deep_remap(type, "__typename") when type not in @non_prefixed_types do # TODO: better
    # IO.inspect(type: type)
    "ValueFlows:#{type}"
  end

  def to_AP_deep_remap(type, "__typename") do
    "#{type}"
  end

  def to_AP_deep_remap(id, "id") do
    Bonfire.Common.URIs.canonical_url(id)
  end

  def to_AP_deep_remap(val, _parent_key) do
    #IO.inspect(deep_key_rename_k: parent_key)
    #IO.inspect(deep_key_rename_v: val)
    val
  end

  def to_AP_remap(val, "__typename", %{"__typename" => "Intent", "provider" => provider}) when not is_nil(provider) do
    {"type", "ValueFlows:Offer"}
  end

  def to_AP_remap(val, "__typename", %{"__typename" => "Intent", "receiver" => receiver}) when not is_nil(receiver) do
    {"type", "ValueFlows:Need"}
  end

  def to_AP_remap(val, parent_key, _) do
    {to_AP_field_rename(parent_key), to_AP_deep_remap(val, parent_key)}
  end

  def to_AP_field_rename(k) do
    with rename_field when is_binary(rename_field) <- @fields_to_AP[k] do
      rename_field
    else _ ->
      k
    end
  end

  def from_AP_deep_remap(map, parent_key \\ nil)

  def from_AP_deep_remap(map = %{}, _parent_key) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) or v == %{} end)
    |> Enum.map(fn {k, v} -> from_AP_remap(v, k) end)
    |> Enum.into(%{})
  end

  def from_AP_deep_remap(list, parent_key) when is_list(list) do
    list
    |> Enum.reject(fn v -> is_nil(v) or v == %{} end)
    |> Enum.map(fn v -> from_AP_deep_remap(v, parent_key) end)
  end

  def from_AP_deep_remap(val, _parent_key) do
    #IO.inspect(deep_key_rename_k: parent_key)
    #IO.inspect(deep_key_rename_v: val)
    val
  end

  def from_AP_remap(val, parent_key) do
    {from_AP_field_rename(parent_key), from_AP_deep_remap(val, parent_key)}
  end

  def from_AP_field_rename(k) do
    with rename_field when is_binary(rename_field) <- @fields_from_AP[k] do
      rename_field
    else _ ->
      k
    end
  end


  def struct_to_json(struct) do
    Jason.encode!(nested_structs_to_maps(struct))
  end


  def activity_object_id(%{object: object}) do
    activity_object_id(object)
  end

  def activity_object_id(%{"object" => object}) do
    activity_object_id(object)
  end

  def activity_object_id(%{data: data}) do
    activity_object_id(data)
  end

  def activity_object_id(%{"id" => id}) do
    id
  end

  # FIXME ?
  def ap_publish(verb, thing_id, user_id) do
    if Bonfire.Common.Utils.module_enabled?(Bonfire.Federate.ActivityPub.APPublishWorker) do
      Bonfire.Federate.ActivityPub.APPublishWorker.enqueue(verb, %{
        "context_id" => thing_id,
        "user_id" => user_id
      })
    end

    {:ok, nil}
  end

  # def ap_publish(_, _, _), do: :ok
end
