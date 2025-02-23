defmodule ValueFlows.Util.Federation do
  use Bonfire.Common.Utils
  alias Bonfire.Common.URIs
  import Bonfire.Common.Config, only: [repo: 0]
  import Untangle

  @log_graphql true

  @actor_types Application.compile_env(:bonfire, :actor_AP_types, [
                 "Person",
                 "Group",
                 "Application",
                 "Service",
                 "Organization"
               ])

  @types_to_AP %{
    # using http://www.ontology-of-units-of-measure.org/resource/om-2/
    "Unit" => "om2:Unit",
    "Measure" => "om2:Measure",
    # using https://www.w3.org/TR/activitystreams-vocabulary/#places
    "SpatialThing" => "Place"
  }
  @types_to_translate Map.keys(@types_to_AP)
  @non_VF_types @actor_types ++ @types_to_translate

  @non_nested_objects [
    "id",
    "url",
    "href",
    "@context",
    "om2",
    "type",
    "und",
    "name",
    "summary",
    "content",
    "ValueFlows",
    "und"
  ]

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
    "tags" => "tag"
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
    :track,
    :trace,
    # see https://www.w3.org/TR/activitystreams-core/#extensibility
    :geom,
    :parent_category_id,
    :sub_categories
  ]

  def ap_publish_activity(
        subject,
        activity_type,
        schema_type,
        thing,
        query_depth \\ 2,
        extra_field_filters \\ []
      )

  def ap_publish_activity(
        subject,
        activity_type,
        schema_type,
        %{id: id} = thing,
        query_depth,
        extra_field_filters
      )
      when is_binary(id) do
    if Bonfire.Common.Extend.module_enabled?(ActivityPub) do
      debug("ValueFlows.Federation - #{activity_type} #{schema_type}")

      with %{} = api_object <-
             fetch_api_object(id, schema_type, query_depth, extra_field_filters),
           %{} = formatted_object <- ap_prepare_object(api_object),
           %{} = activity_params <-
             ap_prepare_activity(
               subject,
               activity_type,
               thing,
               formatted_object
             ) do
        ap_do(activity_type, activity_params)
      else
        e ->
          error(e, "Could not prepare VF object for federation")
      end
    end
  end

  defp ap_do(activity_type, activity_params)
       when activity_type in ["update", "edit", "schedule", "assign", "label"] do
    info(
      activity_params,
      "VF - ap_publish_activity - update"
    )

    with {:ok, activity} <- ActivityPub.update(activity_params) do
      # |> ActivityPub.Federator.Transformer.prepare_outgoing

      {:ok, activity}
    else
      e -> error(e, "Could not update VF object for federation")
    end
  end

  defp ap_do(activity_type, activity_params) when activity_type in ["create", "define"] do
    info(
      activity_params,
      "VF - ap_publish_activity - create"
    )

    with {:ok, activity} <- ActivityPub.create(activity_params) do
      # |> ActivityPub.Federator.Transformer.prepare_outgoing

      debug(struct_to_json(activity.data), "final JSON data")
      # IO.puts(struct_to_json(activity.object.data))

      # if is_map_key(thing, :canonical_url) do
      #   Ecto.Changeset.change(thing, %{canonical_url: activity_object_id(activity)})
      #   |> repo().update()
      # end

      {:ok, activity}
    else
      e -> error(e, "Could not create VF object for federation")
    end
  end

  defp ap_do(
         activity_type,
         activity_params
       )
       when is_atom(activity_type) do
    ap_do(Atom.to_string(activity_type || :create), activity_params)
  end

  defp ap_do(
         activity_type,
         activity_params
       ) do
    warn(
      "ValueFlows.Federation - activities of type #{activity_type} are not yet supported, will simply 'create' instead"
    )

    ap_do("create", activity_params)
  end

  def fetch_api_object(
        id,
        schema_type,
        query_depth \\ 2,
        extra_field_filters \\ []
      ) do
    field_filters = @graphql_ignore_fields ++ extra_field_filters

    debug("ValueFlows.Federation - query all fields except #{inspect(field_filters)}")

    Bonfire.API.GraphQL.QueryHelper.run_query_id(
      id,
      Bonfire.Common.Config.get!(:graphql_schema_module),
      schema_type,
      query_depth,
      &ap_graphql_fields(&1, field_filters),
      @log_graphql
    )
    |> debug("queried via API")

    # rescue
    #   e ->
    #     error(e, "Could not fetch from VF API")
  end

  def ap_prepare_object(obj) do
    obj
    |> to_AP_deep_remap()
    |> info("ValueFlows.Federation - object prepared")
  end

  defp ap_prepare_activity(
         subject,
         _activity_type,
         thing,
         ap_object,
         object_ap_id \\ nil
       ) do
    if module_enabled?(Bonfire.Federate.ActivityPub.AdapterUtils, subject) and
         module_enabled?(ActivityPub.Actor) do
      thing = repo().maybe_preload(thing, creator: [character: [:peered]])

      # |> repo().maybe_preload(:primary_accountable)
      # |> repo().maybe_preload(:provider)
      # |> repo().maybe_preload(:receiver)

      with context <-
             maybe_get_ap_id_by_local_id(Map.get(ap_object, "context")),
           author <-
             subject || maybe_id(thing, :creator) ||
               maybe_id(thing, :primary_accountable) ||
               maybe_id(thing, :provider),
           actor <- ActivityPub.Actor.get_cached!(pointer: uid(subject)),
           object_ap_id <- object_ap_id || URIs.canonical_url(thing),
           ap_object <-
             Map.merge(ap_object, %{
               "id" => object_ap_id,
               "actor" => actor.ap_id,
               "attributedTo" => actor.ap_id
             })
             |> maybe_put("context", context),
           activity_params = %{
             # FIXME: handle remote objects in references
             local: true,
             pointer: uid(thing),
             actor: actor,
             to:
               [
                 # uses an instance-wide default for now
                 if(
                   Bonfire.Common.Config.get_ext(
                     __MODULE__,
                     :boundary_preset,
                     "public"
                   ) == "public",
                   do: Bonfire.Federate.ActivityPub.AdapterUtils.public_uri()
                 ),
                 context,
                 URIs.canonical_url(e(thing, :creator, nil)),
                 e(ap_object, "primaryAccountable", "id", nil),
                 e(ap_object, "provider", "id", nil),
                 e(ap_object, "receiver", "id", nil),
                 e(
                   ap_object,
                   "resourceInventoriedAs",
                   "primaryAccountable",
                   "id",
                   nil
                 )
               ]
               |> filter_empty([])
               |> Enum.uniq()
               |> info("AP recipients"),
             cc: [actor.data["followers"]],
             object: ap_object,
             context: context,
             additional: %{
               "cc" => [actor.data["followers"]]
             }
           } do
        debug(
          activity_params,
          "ValueFlows.Federation - prepared to pass to ActivityPub lib"
        )
      end
    else
      error("VF - No integration available to federate activity")
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
    |> fun.(creator, ...)
  end

  def ap_receive_activity(creator, activity, %{} = object, fun) do
    e(object, :data, object)
    |> debug("ap_receive_activity - object to prepare")
    |> from_AP_deep_remap()
    |> input_to_atoms()
    |> debug("ap_receive_activity - object to create")
    |> Map.put_new(:typename, nil)
    |> ap_receive_activity(ensure_creator(creator, ...), activity, ..., fun)
  end

  defp ensure_creator(%{} = creator, _object) do
    creator
  end

  defp ensure_creator(_, %{creator: %{} = creator}) do
    creator
  end

  defp ensure_creator(_, %{actor: %{} = creator}) do
    creator
  end

  defp ensure_creator(_, %{primary_accountable: %{} = creator}) do
    creator
  end

  defp ensure_creator(_, %{provider: %{} = creator}) do
    creator
  end

  defp ensure_creator(_, _) do
    nil
  end

  # TODO better
  defp maybe_get_ap_id_by_local_id("http" <> _ = url) do
    url
  end

  defp maybe_get_ap_id_by_local_id(id) when is_binary(id) do
    ActivityPub.Actor.get_cached!(pointer: id)
    |> e(:ap_id, nil)
  end

  defp maybe_get_ap_id_by_local_id(%{id: id}),
    do: maybe_get_ap_id_by_local_id(id)

  defp maybe_get_ap_id_by_local_id(%{"id" => id}),
    do: maybe_get_ap_id_by_local_id(id)

  defp maybe_get_ap_id_by_local_id(_), do: nil

  def ap_graphql_fields(e, field_filters \\ []) do
    # debug(e)

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
    |> Enum.reject(fn {_, v} -> empty?(v) end)
    # FIXME: this shouldn't be necessary if ap_graphql_fields_filter correctly filters them all from the query
    |> Enum.reject(fn {k, _} ->
      Enum.member?(@graphql_ignore_fields, maybe_to_snake_atom(k))
    end)
    |> Enum.map(fn {k, v} -> to_AP_remap(v, k, map) end)
    |> Enum.into(%{})
  end

  defp to_AP_deep_remap(list, parent_key) when is_list(list) do
    list
    |> Enum.reject(fn v -> empty?(v) end)
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
    # debug(deep_key_rename_k: parent_key)
    # debug(deep_key_rename_v: val)
    val
  end

  # defp to_AP_remap(val, "__typename", %{"__typename" => "Intent", "provider" => provider} = _parent_map) when not is_nil(provider) do
  #   {"type", "ValueFlows:Offer"}
  # end

  # defp to_AP_remap(val, "__typename", %{"__typename" => "Intent", "receiver" => receiver} = _parent_map) when not is_nil(receiver) do
  #   {"type", "ValueFlows:Need"}
  # end

  defp to_AP_remap(action_id, "action", _parent_map)
       when is_binary(action_id) do
    ld_action_id =
      if Enum.member?(
           ValueFlows.Knowledge.Action.Actions.default_actions(),
           action_id
         ) do
        "https://w3id.org/valueflows#" <> action_id
      else
        Bonfire.Common.URIs.canonical_url(action_id)
      end

    {"action", ld_action_id}
  end

  defp to_AP_remap(%{"id" => action_id}, "action", _parent_map),
    do: to_AP_remap(action_id, "action", nil)

  defp to_AP_remap(id, "id", parent_map) when is_binary(id) do
    # debug(url: parent_map)
    {"id", Bonfire.Common.URIs.canonical_url(parent_map)}
  end

  defp to_AP_remap(val, parent_key, _parent_map) do
    if is_map(val) && Map.get(val, "id") && length(Map.keys(val)) == 1 do
      # when an object has just an ID
      {to_AP_field_rename(parent_key), Bonfire.Common.URIs.canonical_url(Map.get(val, "id"))}
    else
      {to_AP_field_rename(parent_key), to_AP_deep_remap(val, parent_key)}
    end
  end

  defp to_AP_field_rename(k) do
    with rename_field when is_binary(rename_field) <- @fields_to_AP[k] do
      rename_field
    else
      _ ->
        k
    end
  end

  defp from_AP_deep_remap(map, parent_key \\ nil)

  defp from_AP_deep_remap(map = %{}, _parent_key) when not is_struct(map) do
    map
    |> Enum.reject(fn {_, v} -> empty?(v) end)
    |> Enum.map(fn {k, v} -> {from_AP_field_rename(k), from_AP_remap(v, k)} end)
    |> Enum.into(%{})
  end

  defp from_AP_deep_remap(list, parent_key) when is_list(list) do
    list
    |> Enum.reject(fn v -> empty?(v) end)
    |> Enum.map(fn v -> from_AP_remap(v, parent_key) end)
  end

  defp from_AP_deep_remap(val, _parent_key) do
    # debug(deep_key_rename_k: parent_key)
    # debug(deep_key_rename_v: val)
    val
  end

  defp from_AP_remap("https://w3id.org/valueflows#" <> action_name, "action")
       when is_binary(action_name) do
    action_name
  end

  # first create embeded nested objects that have actor/author info
  defp from_AP_remap(
         %{"actor" => creator, "type" => _, "id" => _} = object,
         parent_key
       )
       when not is_nil(creator) do
    maybe_create_nested_object(creator, object, parent_key)
  end

  defp from_AP_remap(
         %{"attributedTo" => creator, "type" => _, "id" => _} = object,
         parent_key
       )
       when not is_nil(creator) do
    maybe_create_nested_object(creator, object, parent_key)
  end

  defp from_AP_remap(
         %{"primaryAccountable" => creator, "type" => _, "id" => _} = object,
         parent_key
       )
       when not is_nil(creator) do
    maybe_create_nested_object(creator, object, parent_key)
  end

  defp from_AP_remap(
         %{"provider" => creator, "type" => _, "id" => _} = object,
         parent_key
       )
       when not is_nil(creator) do
    maybe_create_nested_object(creator, object, parent_key)
  end

  defp from_AP_remap(
         %{"receiver" => creator, "type" => _, "id" => _} = object,
         parent_key
       )
       when not is_nil(creator) do
    maybe_create_nested_object(creator, object, parent_key)
  end

  # then create agents
  defp from_AP_remap(%{"type" => type, "id" => _} = object, parent_key)
       when type in @actor_types do
    maybe_create_nested_object(nil, object, parent_key)
  end

  defp from_AP_remap(%{"agentType" => _, "id" => _} = object, parent_key) do
    maybe_create_nested_object(nil, object, parent_key)
  end

  # then try to handle objects without known authorship (maybe we should be re-fetching these?)
  defp from_AP_remap(%{"type" => _, "id" => _} = object, parent_key) do
    maybe_create_nested_object(nil, object, parent_key)
  end

  # then handle any non-embeded objects
  defp from_AP_remap(val, parent_key)
       when is_binary(val) and parent_key not in @non_nested_objects do
    with true <- Bonfire.Common.URIs.valid_url?(val),
         %{} = nested_object <- maybe_create_nested_object(nil, val, parent_key) do
      info(
        nested_object,
        "created nested object from URI"
      )
    else
      false ->
        debug({val, parent_key}, "do not create nested object")
        from_AP_deep_remap(val, parent_key)

      e ->
        error(
          e,
          "Failed to create nested object for #{parent_key} : #{inspect(val)}"
        )

        from_AP_deep_remap(val, parent_key)
    end
  end

  defp from_AP_remap(val, parent_key) do
    from_AP_deep_remap(val, parent_key)
  end

  defp from_AP_field_rename(k) do
    with rename_field when is_binary(rename_field) <- @fields_from_AP[k] do
      rename_field
    else
      _ ->
        k
    end
  end

  # loop through nested objects
  def maybe_create_nested_object(creator, object_or_id, _parent_key) do
    id = e(object_or_id, "id", object_or_id)

    already_processed =
      if id do
        case Process.get("uri_object:#{id}", false) do
          false ->
            nil

          nested_object ->
            info(nested_object, "retrieved from Process dict")
            {:ok, nested_object}
        end
      end

    with {:ok, created_object} <-
           already_processed ||
             Bonfire.Federate.ActivityPub.Incoming.receive_object(
               creator,
               object_or_id
             ) do
      if !already_processed && id do
        Process.put("uri_object:#{id}", created_object)
        info(id, "stored in Process dict")
      end

      info(
        created_object,
        "created nested object"
      )
    else
      _ ->
        # should we just return the original?
        nil
    end
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
  def ap_publish(user, verb, thing) do
    if module = maybe_module(Bonfire.Federate.ActivityPub.Outgoing, user) do
      module.maybe_federate(user, verb, thing)
    else
      :ignore
    end
  end

  # def ap_publish(_, _, _), do: :ok
end
