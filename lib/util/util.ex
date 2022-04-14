# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Util do
  use Bonfire.Common.Utils
  import Bonfire.Common.Config, only: [repo: 0]

  import Where

  def common_filters(q, unknown_filter) do
    # TODO: implement boundary checking here
    error(unknown_filter, "Unknown query filter, skipping")
    q
  end

  def ensure_edit_permission(%{} = user, %{} = object) do
    # TODO refactor to also use Boundaries (when extension active)
    # TODO check also based on the parent / context? and user's organisation? etc
    if ValueFlows.Util.is_admin?(user) or Map.get(object, :creator_id) == user.id or Map.get(object, :provider_id) == user.id do
      :ok
    else
      {:error, :not_permitted}
    end
  end


  def publish(%{id: creator_id} = creator, verb, %{id: thing_id} =thing) do

    opts = set_boundaries(creator, thing) # this sets permissions & returns recipients in opts to be used for publishing

    # ValueFlows.Util.Federation.ap_publish("create", thing_id, creator_id) # deprecate - AP publishing is triggered by FeedActivities.publish instead

    if module_enabled?(Bonfire.Social.FeedActivities) and Kernel.function_exported?(Bonfire.Social.FeedActivities, :publish, 4) do

      # add to activity feed + maybe federate
      Bonfire.Social.FeedActivities.publish(creator, verb, thing, opts)

    else
      debug("VF - No integration available to publish activity")
      {:ok, nil}
    end
  end

  def publish(_creator, verb, %{id: thing_id} =thing) do
    debug("VF - No creator for object so we can't publish it")

    # make visible
    set_boundaries(e(thing, :creator, e(thing, :provider, nil)), thing)

    {:ok, nil}
  end

  def set_boundaries(creator, thing) do
    # TODO: make default audience configurable & per object audience selectable by user in API and UI (note: also in `Federation.ap_prepare_activity`)
    preset_boundary = Bonfire.Common.Config.get_ext(__MODULE__, :preset_boundary, "public")

    to_circles = Bonfire.Common.Config.get_ext(__MODULE__, :publish_to_default_circles, [])
              ++ [
                e(thing, :context_id, nil),
                e(thing, :provider_id, nil),
                e(thing, :receiver_id, nil)
              ]

    to_feeds = if module_enabled?(Bonfire.Social.Feeds), do:
                  Bonfire.Social.Feeds.feed_ids(:notifications, [
                    e(thing, :context_id, nil),
                    e(thing, :provider_id, nil),
                    e(thing, :receiver_id, nil)
              ])

    opts = [boundary: preset_boundary, to_circles: to_circles, to_feeds: to_feeds]
    debug(opts, "boundaries to set & recipients to include (should include scope, provider, and receiver if any)")

    if module_enabled?(Bonfire.Boundaries), do: Bonfire.Boundaries.set_boundaries(creator, thing, opts)

    opts
  end

  def publish(%{creator_id: creator_id, id: thing_id}, :update) do
    # TODO: wrong if edited by admin
    ValueFlows.Util.Federation.ap_publish("update", thing_id, creator_id)
  end

  def publish(%{creator_id: creator_id, id: thing_id}, :updated) do # deprecate
    publish(%{creator_id: creator_id, id: thing_id}, :update)
  end

  def publish(%{creator_id: creator_id, id: thing_id}, :delete) do
    # TODO: wrong if edited by admin
    ValueFlows.Util.Federation.ap_publish("delete", thing_id, creator_id)
  end

  def publish(%{creator_id: creator_id, id: thing_id}, :deleted) do # deprecate
    publish(%{creator_id: creator_id, id: thing_id}, :delete)
  end

  def publish(_, verb) do
    warn("Could not publish (#{verb})")
    {:ok, nil}
  end

  def attr_get_agent(attrs, field, creator) do
    case Map.get(attrs, field) do
      "me" -> ulid(creator)
      id_or_uri_or_username when is_binary(id_or_uri_or_username) -> ulid(id_or_uri_or_username) || Bonfire.Federate.ActivityPub.Utils.get_by_url_ap_id_or_username(id_or_uri_or_username) |> ulid()
      other -> ulid(other)
    end
  end

  def search_for_matches(%{name: name, note: note, is_offer: true}) do
    facets = %{index_type: "ValueFlows.Planning.Need"}
    Bonfire.Search.Fuzzy.search_filtered(name, facets) || Bonfire.Search.Fuzzy.search_filtered(note, facets)
  end
  def search_for_matches(%{name: name, note: note, is_need: true}) do
    facets = %{index_type: "ValueFlows.Planning.Offer"}
    Bonfire.Search.Fuzzy.search_filtered(name, facets) || Bonfire.Search.Fuzzy.search_filtered(note, facets)
  end

  def search_for_matches(%{name: name, note: note}) do
    Bonfire.Search.Fuzzy.search(name) || Bonfire.Search.Fuzzy.search(note)
  end

  def index_for_search(object) do
    if module_enabled?(Bonfire.Search.Indexer) do
      Bonfire.Search.Indexer.maybe_index_object(object)
    else
      :ok
    end
  end

  def indexing_format_creator(%{creator_id: id} = obj) when not is_nil(id) do
    Bonfire.Repo.maybe_preload(obj,
      [creator: [
        :character,
        profile: [:icon],
      ]]
    )
    |> Map.get(:creator)
    |> indexing_format_creator()
  end

  def indexing_format_creator(%Pointers.Pointer{} = pointer) do
    Bonfire.Common.Pointers.get(pointer) |> indexing_format_creator()
  end

  def indexing_format_creator(%{id: id} = creator) when not is_nil(id) do
    Bonfire.Me.Integration.indexing_format(maybe_get(creator, :profile), maybe_get(creator, :character))
  end

  def indexing_format_creator(_) do
    nil
  end

  def indexing_format_tags(obj) do
    if module_enabled?(Bonfire.Tag.Tags) do
      repo().maybe_preload(obj, tags: [:profile])
      |> Map.get(:tags, [])
      |> Enum.map(&Bonfire.Tag.Tags.indexing_object_format_name/1)
    end
  end

  def maybe_search(search, facets) do
    maybe_apply(Bonfire.Search, :search_by_type, [search, facets], &none/2)
  end
  defp none(_, _), do: nil


  def image_url(%{icon_id: icon_id} = thing) when not is_nil(icon_id) do
    # debug(thing)
    # debug(icon_id)
    # debug(thing.icon)
    Bonfire.Common.Utils.avatar_url(thing)
  end

  def image_url(%{image_id: image_id} = thing) when not is_nil(image_id) do
    # debug(image_url: thing)
    Bonfire.Common.Utils.image_url(thing)
  end

  # def image_url(%{icon_id: icon_id} = thing) when not is_nil(icon_id) do
  #   Bonfire.Repo.maybe_preload(thing, icon: [:content_upload, :content_mirror])
  #   # |> debug()
  #   |> Map.get(:icon)
  #   |> content_url_or_path()
  # end

  # def image_url(%{image_id: image_id} = thing) when not is_nil(image_id) do
  #   #debug(thing)
  #   Bonfire.Repo.maybe_preload(thing, image: [:content_upload, :content_mirror])
  #   |> Map.get(:image)
  #   |> content_url_or_path()
  # end

  # def image_url(%{profile: _} = thing) do
  #   Bonfire.Repo.maybe_preload(thing, profile: [image: [:content_upload, :content_mirror], icon: [:content_upload, :content_mirror]])
  #   |> Map.get(:profile)
  #   |> image_url()
  # end

  def image_url(_) do
    nil
  end

  def content_url_or_path(content) do
    e(
      content,
      :content_upload,
      :path,
      e(content, :content_mirror, :url, nil)
    )
  end

  def handle_changeset_errors(cs, attrs, fn_list) do
    Enum.reduce_while(fn_list, cs, fn cs_handler, cs ->
      case cs_handler.(cs, attrs) do
        {:error, reason} -> {:halt, {:error, reason}}
        cs -> {:cont, cs}
      end
    end)
    |> case do
      {:error, _} = e -> e
      cs -> {:ok, cs}
    end
  end

  def is_admin?(user) do
    if Map.get(user, :instance_admin) do
      Map.get(user.instance_admin, :is_instance_admin, false)
    else
      false # FIXME
    end
  end

  def user_schema() do
    # Bonfire.Common.Extend.maybe_schema_or_pointer(Bonfire.Common.Config.get(:user_schema, Bonfire.Data.Identity.User))
    Pointers.Pointer
  end

  def org_schema() do
    # Bonfire.Common.Extend.maybe_schema_or_pointer(Bonfire.Common.Config.get(:organisation_schema, user_schema()))
    Pointers.Pointer
  end

  def user_or_org_schema() do
    user_schema()
  end

  def image_schema() do
    Bonfire.Common.Extend.maybe_schema_or_pointer(Bonfire.Common.Config.get(:files_media_schema, Bonfire.Files.Media))
  end

  def change_measures(changeset, %{} = attrs, measure_fields) do
    # TODO: combine parse_measurement_attrs with this one?

    measures = Map.take(attrs, measure_fields)

    Enum.reduce(measures, changeset, fn {field_name, measure}, c ->
      put_measure(c, field_name, measure)
    end)
  end

  defp put_measure(c, field_name, measure) when is_struct(measure) do
    Ecto.Changeset.put_assoc(c, field_name, measure)
  end
  defp put_measure(c, field_name, measure) do
    Ecto.Changeset.cast_assoc(c, field_name, with: &Bonfire.Quantify.Measure.validate_changeset/2)
  end

  def parse_measurement_attrs(attrs, user \\ nil) do
    Enum.reduce(attrs, %{}, fn

      {k, %{has_unit: unit} = v}, acc ->

        Map.put(acc, k,
          with false <- is_ulid?(unit),
          {:error, e} <- Bonfire.Quantify.Units.get_or_create(unit, user) do

            error(e)
            raise {:error, "Invalid unit used for quantity"}

          else
            {:ok, %{id: id} = found_or_created_unit} ->

              v
              |> Map.put(:unit, found_or_created_unit)
              |> Map.put(:unit_id, id)
              |> Map.drop([:has_unit])

            _ ->
              map_key_replace(v, :has_unit, :unit_id)
          end
        )

      {k, v}, acc ->
        Map.put(acc, k, v)

    end)
  end

  # def parse_measurement_attrs(attrs) do
  #   for {k, v} <- attrs, into: %{} do
  #     v =
  #       if is_map(v) and Map.has_key?(v, :has_unit) do
  #         map_key_replace(v, :has_unit, :unit_id)
  #       else
  #         v
  #       end

  #     {k, v}
  #   end
  # end

  def default_recurse_limit(), do: 2 # TODO: configurable
  def max_recurse_limit(), do: 1000 # TODO: configurable

    @doc """
  lookup tag from URL(s), to support vf-graphql mode
  """

  # def try_tag_thing(_user, thing, %{resource_classified_as: urls})
  #     when is_list(urls) and length(urls) > 0 do
  #   # todo: lookup tag by URL
  #   {:ok, thing}
  # end

  def maybe_classification(user, tags) when is_list(tags), do: Enum.map(tags, &maybe_classification(user, &1))
  def maybe_classification(user, %{value: tag}), do: maybe_classification(user, tag)
  def maybe_classification(user, tag) do
    with {:ok, c} <- Bonfire.Tag.Tags.maybe_find_tag(user, tag) do
      c
    end
  end

  def maybe_classification_id(user, tags) when is_list(tags) do
    Enum.map(tags, &maybe_classification_id(user, &1))
  end
  def maybe_classification_id(user, tag) do
    maybe_classification(user, tag) |> e(:id, nil)
  end

  def try_tag_thing(user, thing, %{} = attrs) do
    if module_enabled?(Bonfire.Tag.Tags) do

      input_tags = Map.get(attrs, :tags, []) ++ Map.get(attrs, :resource_classified_as, []) ++ Map.get(attrs, :classified_as, [])

      try_tag_thing(user, thing, input_tags)
    else
      {:ok, thing}
    end
  end

  def try_tag_thing(user, thing, tags) when is_list(tags) do
    if module_enabled?(Bonfire.Tag.Tags) do
      Bonfire.Tag.Tags.maybe_tag(user, thing, tags)
    else
      {:ok, thing}
    end
  end


  def map_values(%{} = map, func) do
    for {k, v} <- map, into: %{}, do: {k, func.(v)}
  end


end
