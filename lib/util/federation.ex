defmodule ValueFlows.Util.Federation do
  use Bonfire.Common.Utils
  alias Bonfire.Common.URIs
  import Where

  @log_graphql false

  @schema Bonfire.Common.Config.get!(:graphql_schema_module)

  @types_to_AP %{
    "Unit" => "om2:Unit", # using http://www.ontology-of-units-of-measure.org/resource/om-2/
    "Measure" => "om2:Measure",
    "SpatialThing" => "Place", # using https://www.w3.org/TR/activitystreams-vocabulary/#places
  }
  @types_to_translate Map.keys(@types_to_AP)
  @non_VF_types ["Person", "Organization"] ++ @types_to_translate

  @fields_to_AP %{
    "__typename" => "type",
    "canonicalUrl" => "id",
    "inScopeOf" => "context",
    "creator" => "attributedTo",
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
    # :unit_based,
    :my_like,
    :my_flag,
    :feature_count,
    :follower_count,
    :is_local,
    :is_disabled,
    :page_info,
    :edges,
    :threads,
    :outbox,
    :inbox,
    :notifications,
    :followers,
    :community_follows,
    :communities,
    :collections,
    :intents,
    :processes,
    :proposals,
    :economic_events,
    :inputs,
    :outputs,
    :intended_inputs,
    :intended_outputs,
    :inventoried_economic_resources,
    :tagged,
    :geom, # see https://www.w3.org/TR/activitystreams-core/#extensibility
  ]

  def ap_publish_activity(
        activity_type,
        schema_type,
        thing,
        query_depth \\ 2,
        extra_field_filters \\ []
      )

  def ap_publish_activity(
        activity_type,
        schema_type,
        %{id: id} = thing,
        query_depth,
        extra_field_filters
      )
    when is_binary(id) do

    if Bonfire.Common.Extend.module_enabled?(ActivityPub) do

      debug("ValueFlows.Federation - #{activity_type} #{schema_type}")

      with %{} = api_object <- fetch_api_object(id, schema_type, query_depth, extra_field_filters) |> ap_prepare_object(),
           %{} = activity_params <- ap_prepare_activity(
              activity_type,
              thing,
              api_object
            ) do
        ap_do(activity_type, activity_params, id)
      end
    end
  end


  def ap_do("create", activity_params, id) do
    with {:ok, activity} <- ActivityPub.create(activity_params, id) do

      activity
      # |> ActivityPubWeb.Transmogrifier.prepare_outgoing
      |> debug("VF - ap_publish_activity - create")

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

  def ap_do("update", activity_params, _id) do
    with {:ok, activity} <- ActivityPub.update(activity_params) do

      activity
      # |> ActivityPubWeb.Transmogrifier.prepare_outgoing
      |> debug("VF - ap_publish_activity - update")

      {:ok, activity}
    else
      e -> {:error, e}
    end
  end

  def ap_do(
        activity_type,
        _activity_params,
        _id
      ) do
      throw {:error, "ValueFlows.Federation - activities of type #{activity_type} are not yet supported, so skip federation"}
  end

  def fetch_api_object(id, schema_type, query_depth \\ 2, extra_field_filters \\ []) do
    field_filters = @graphql_ignore_fields ++ extra_field_filters

    debug("ValueFlows.Federation - query all fields except #{inspect field_filters}")

    with obj <-
           Bonfire.API.GraphQL.QueryHelper.run_query_id(
             id,
             @schema,
             schema_type,
             query_depth,
             &ap_graphql_fields(&1, field_filters),
             @log_graphql
           ) do

      # debug(obj, "queried via API")

      obj
    end

  rescue e ->
    error(e)
    {:error, e}
  end

  def ap_prepare_object(obj) do
    obj
    |> to_AP_deep_remap()
    |> debug("ValueFlows.Federation - object prepared")
  end

  def ap_prepare_activity(_activity_type, thing, ap_object, author_id \\ nil, object_ap_id \\ nil) do

    if Bonfire.Common.Extend.module_enabled?(Bonfire.Federate.ActivityPub.Utils) do

      with context <-
            maybe_get_ap_id_by_local_id(Map.get(ap_object, "context") |> dump),
          author <-
            author_id || maybe_id(thing, :creator) || maybe_id(thing, :primary_accountable) ||
              maybe_id(thing, :provider) || maybe_id(thing, :receiver),
          actor <- Bonfire.Federate.ActivityPub.Utils.get_cached_actor_by_local_id!(author),
          object_ap_id <- object_ap_id || URIs.canonical_url(thing),
          ap_object <-
            Map.merge(ap_object, %{
              "id" => object_ap_id,
              "actor" => actor.ap_id,
              "attributedTo" => actor.ap_id
            })
            |> maybe_put("context", context),
          activity_params = %{
            local: true, # FIXME: handle remote objects in references
            actor: actor,
            to: [
                Bonfire.Federate.ActivityPub.Utils.public_uri(), # FIMXE: only for public objects
                context,
                URIs.canonical_url(e(thing, :primary_accountable, nil)),
                URIs.canonical_url(e(thing, :provider, nil)),
                URIs.canonical_url(e(thing, :receiver, nil)),
              ]
              |> filter_empty([]),
            cc: [],
            object: ap_object,
            context: context,
            additional: %{
              "cc" => [actor.data["followers"]]
            }
          } do
        activity_params
        |> debug("ValueFlows.Federation - activity prepared")
      end
    else
      debug("VF - No integration available to federate activity")
    end
  end


  @doc """
  Incoming federation
  """
  def ap_receive_activity(creator, _activity, %{typename: _} = attrs, fun) do
    # TODO: target guest circle if activity.public==true
    # TODO: target right circles/boundaries based on to/cc
    attrs
    |> debug("ap_receive_activity - attrs to create")

    fun.(creator, attrs)
  end

  def ap_receive_activity(creator, activity, %{} = object, fun) do
    attrs = e(object, :data, object)
    |> debug("ap_receive_activity - object to prepare")
    |> from_AP_deep_remap()
    |> input_to_atoms()
    |> Map.put_new(:typename, nil)

    ap_receive_activity(creator, activity, attrs, fun)
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
    #debug(e)

    ap_graphql_fields_filter(e, field_filters)
    # |> debug("ap_graphql_fields")
  end


  defp ap_graphql_fields_filter(e, field_filters \\ []) do

    case e do
      {key, {key2, val}} ->
        if key not in field_filters and key2 not in field_filters and
             is_list(val) do
          {key, {key2, for(n <- val, do: ap_graphql_fields_filter(n, field_filters))}}
          # else
          #   debug(hmm1: e)
        end

      {key, val} ->
        if key not in field_filters and is_list(val) do
          {key, for(n <- val, do: ap_graphql_fields_filter(n, field_filters))}
          # else
          #   debug(hmm2: e)
        end

      _ ->
        if e not in field_filters, do: e
    end
    # |> debug("ap_graphql_fields_filter")
  end

  defp to_AP_deep_remap(map, parent_key \\ nil)

  defp to_AP_deep_remap(map = %{}, parent_key) when not is_struct(map) do
    map
    |> Enum.reject(fn {_, v} -> is_empty(v) end)
    |> Enum.reject(fn {k, _} -> Enum.member?(@graphql_ignore_fields, maybe_to_snake_atom(k)) end) # FIXME: this shouldn't be necessary if ap_graphql_fields_filter correctly filters them all from the query
    |> Enum.map(fn {k, v} -> to_AP_remap(v, k, map) end)
    |> Enum.into(%{})
  end

  defp to_AP_deep_remap(list, parent_key) when is_list(list) do
    list
    |> Enum.reject(fn v -> is_empty(v) end)
    |> Enum.map(fn v -> to_AP_deep_remap(v, parent_key) end)
  end

  defp to_AP_deep_remap(type, "__typename") when type in @types_to_translate do
    @types_to_AP[type]
  end

  defp to_AP_deep_remap(type, "__typename") when type not in @non_VF_types do
    "ValueFlows:#{type}"
  end

  defp to_AP_deep_remap(type, "__typename") do
    "#{type}"
  end

  defp to_AP_deep_remap(id, "id") do
    Bonfire.Common.URIs.canonical_url(id)
  end

  defp to_AP_deep_remap(val, _parent_key) do
    #debug(deep_key_rename_k: parent_key)
    #debug(deep_key_rename_v: val)
    val
  end

  # defp to_AP_remap(val, "__typename", %{"__typename" => "Intent", "provider" => provider} = _parent_map) when not is_nil(provider) do
  #   {"type", "ValueFlows:Offer"}
  # end

  # defp to_AP_remap(val, "__typename", %{"__typename" => "Intent", "receiver" => receiver} = _parent_map) when not is_nil(receiver) do
  #   {"type", "ValueFlows:Need"}
  # end

  defp to_AP_remap(action_id, "action", _parent_map) when is_binary(action_id) do
    ld_action_id = if Enum.member?(ValueFlows.Knowledge.Action.Actions.default_actions, action_id) do
      "https://w3id.org/valueflows#"<>action_id
    else
      Bonfire.Common.URIs.canonical_url(action_id)
    end

    {"action", ld_action_id}
  end
  defp to_AP_remap(%{"id"=>action_id}, "action", _parent_map), do: to_AP_remap(action_id, "action", nil)

  defp to_AP_remap(id, "id", parent_map) when is_binary(id) do
    # debug(url: parent_map)
    {"id", Bonfire.Common.URIs.canonical_url(parent_map)}
  end

  defp to_AP_remap(val, parent_key, _parent_map) do
    if is_map(val) && Map.get(val, "id") && length(Map.keys(val))==1 do
      # when an object has just an ID
      {to_AP_field_rename(parent_key), Bonfire.Common.URIs.canonical_url(Map.get(val, "id"))}
    else
      {to_AP_field_rename(parent_key), to_AP_deep_remap(val, parent_key)}
    end
  end

  defp to_AP_field_rename(k) do
    with rename_field when is_binary(rename_field) <- @fields_to_AP[k] do
      rename_field
    else _ ->
      k
    end
  end


  defp from_AP_deep_remap(map, parent_key \\ nil)

  defp from_AP_deep_remap(map = %{}, _parent_key) when not is_struct(map) do
    map
    |> Enum.reject(fn {_, v} -> is_empty(v) end)
    |> Enum.map(fn {k, v} -> {from_AP_field_rename(k), from_AP_remap(v, k)} end)
    |> Enum.into(%{})
  end

  defp from_AP_deep_remap(list, parent_key) when is_list(list) do
    list
    |> Enum.reject(fn v -> is_empty(v) end)
    |> Enum.map(fn v -> from_AP_remap(v, parent_key) end)
  end

  defp from_AP_deep_remap(val, _parent_key) do
    #debug(deep_key_rename_k: parent_key)
    #debug(deep_key_rename_v: val)
    val
  end


  defp from_AP_remap(%{"type" => _, "actor" => creator} = val, parent_key) when not is_nil(creator) do
    create_nested_object(creator, val, parent_key)
  end
  defp from_AP_remap(%{"type" => _, "attributedTo" => creator} = val, parent_key) when not is_nil(creator) do
    create_nested_object(creator, val, parent_key)
  end
  defp from_AP_remap(%{"type" => _, "primaryAccountable" => creator} = val, parent_key) when not is_nil(creator) do
    create_nested_object(creator, val, parent_key)
  end
  defp from_AP_remap(%{"type" => _, "provider" => creator} = val, parent_key) when not is_nil(creator) do
    create_nested_object(creator, val, parent_key)
  end
  defp from_AP_remap(%{"type" => _, "receiver" => creator} = val, parent_key) when not is_nil(creator) do
    create_nested_object(creator, val, parent_key)
  end
  defp from_AP_remap(%{"agentType" => _} = val, parent_key) do
    create_nested_object(val, val, parent_key)
  end
  defp from_AP_remap(%{"type" => _} = val, parent_key) do
    # handle types without a known creator (should we be re-fetching the object?)
    create_nested_object(nil, val, parent_key)
  end

  defp from_AP_remap(val, parent_key) do
    from_AP_deep_remap(val, parent_key)
  end

  defp from_AP_field_rename(k) do
    with rename_field when is_binary(rename_field) <- @fields_from_AP[k] do
      rename_field
    else _ ->
      k
    end
  end

  def create_nested_object(creator, val, _parent_key) do # loop through nested objects
    with {:ok, nested_object} <- Bonfire.Federate.ActivityPub.Receiver.receive_object(creator, val)
    |> debug("created nested object")
    do
      nested_object
    # else _ ->
    #   {from_AP_field_rename(parent_key), from_AP_deep_remap(val, parent_key)}
    end
  end


  def is_empty(v) do
    is_nil(v) or v == %{} or v == [] or v == ""
  end

  def struct_to_json(struct) do
    Jason.encode!(nested_structs_to_maps(struct))
  end

  def maybe_id(thing, key) do
    e(thing, key, :id, nil) || e(thing, "#{key}_id", nil) || e(thing, key, nil)
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
    if Bonfire.Common.Extend.module_enabled?(Bonfire.Federate.ActivityPub.APPublishWorker) do
      Bonfire.Federate.ActivityPub.APPublishWorker.enqueue(verb, %{
        "context_id" => thing_id,
        "user_id" => user_id
      })
    end

    {:ok, nil}
  end

  # def ap_publish(_, _, _), do: :ok
end
