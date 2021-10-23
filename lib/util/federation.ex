defmodule ValueFlows.Util.Federation do
  import Bonfire.Common.Utils
  require Logger

  @log_graphql false

  @schema Bonfire.Common.Config.get!(:graphql_schema_module)
  @all_types Bonfire.Common.Config.get!(:all_types) || []

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
    :community_follows
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

      with api_object <- ap_prepare_object(id, schema_type, query_depth, extra_field_filters),
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

  def ap_prepare_object(id, schema_type, query_depth \\ 2, extra_field_filters \\ []) do
    field_filters = @graphql_ignore_fields ++ extra_field_filters

    Logger.info("ValueFlows.Federation - query all fields except #{inspect field_filters}")

    with obj <-
           Bonfire.GraphQL.QueryHelper.run_query_id(
             id,
             @schema,
             schema_type,
             query_depth,
             &ap_graphql_fields_filter(&1, field_filters),
             @log_graphql
           )
           |> ap_deep_key_rename() do
      IO.inspect(obj, label: "prepared for federation")

      obj
    end

  rescue e ->
    Logger.error(e)
    {:error, e}
  end

  def ap_prepare_activity("create", thing, object, author_id \\ nil) do

    if Bonfire.Common.Utils.module_enabled?(Bonfire.Federate.ActivityPub.Utils) do

      with context <-
            maybe_get_ap_id_by_local_id(Map.get(thing, :context_id)),
          author <-
            author_id || Map.get(thing, :creator_id) || Map.get(thing, :primary_accountable_id) ||
              Map.get(thing, :provider_id) || Map.get(thing, :receiver_id),
          actor <- Bonfire.Federate.ActivityPub.Utils.get_cached_actor_by_local_id!(author),
          ap_id <- Bonfire.Federate.ActivityPub.Utils.generate_object_ap_id(thing),
          object <-
            Map.merge(object, %{
              "id" => ap_id,
              "actor" => actor.ap_id,
              "attributedTo" => actor.ap_id
            })
            |> maybe_put("context", context)
            |> maybe_put("name", Map.get(thing, :name, Map.get(thing, :label)))
            #  |> maybe_put(
            #    "summary",
            #    Map.get(thing, :note, Map.get(thing, :summary))
            #  )
            |> maybe_put("icon", Map.get(object, "image")),
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

  def ap_receive_activity(creator, activity, object, fun) do
    # TODO: target guest circle if activity.public==true
    # TODO: target right circles/boundaries based on to/cc
    IO.inspect(activity: activity)
    # IO.inspect(object: object)
    attrs = e(object, :data, object)
    |> input_to_atoms()
    |> IO.inspect(label: "attrs")

    fun.(creator, attrs)
  end

  defp maybe_get_ap_id_by_local_id(id) when is_binary(id) do
    Bonfire.Federate.ActivityPub.Utils.get_cached_actor_by_local_id!(id) |> e(:ap_id, nil)
  end
  defp maybe_get_ap_id_by_local_id(_), do: nil

  def ap_graphql_fields_filter(e, field_filters \\ []) do
    #IO.inspect(e)

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
  end

  def ap_deep_key_rename(map, parent_key \\ nil)

  def ap_deep_key_rename(map = %{}, _parent_key) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) or v == %{} end)
    |> Enum.map(fn {k, v} -> {ap_field_rename(k), ap_deep_key_rename(v, k)} end)
    |> Enum.into(%{})
  end

  def ap_deep_key_rename(list, parent_key) when is_list(list) do
    list
    |> Enum.reject(fn v -> is_nil(v) or v == %{} end)
    |> Enum.map(fn v -> ap_deep_key_rename(v, parent_key) end)

    # |> Enum.into(%{})
  end

  def ap_deep_key_rename(val, parent_key)
      when parent_key == "__typename" and val not in @all_types do
    "ValueFlows:#{val}"
  end

  def ap_deep_key_rename(val, parent_key) when parent_key == "id" do
    Bonfire.Common.URIs.canonical_url(val)
  end

  def ap_deep_key_rename(val, _parent_key) do
    #IO.inspect(deep_key_rename_k: parent_key)
    #IO.inspect(deep_key_rename_v: val)
    val
  end

  def ap_field_rename(k) do
    case k do
      "__typename" -> "type"
      "canonicalUrl" -> "id"
      "creator" -> "actor"
      "displayUsername" -> "preferredUsername"
      "created" -> "published"
      # "hasBeginning" -> "published"
      _ -> k
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
