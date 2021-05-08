# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Util do
  import Bonfire.Common.Utils
  import Bonfire.Common.Config, only: [repo: 0]
  @user Bonfire.Common.Config.get!(:user_schema)
  @image_schema Bonfire.Files.Media

  require Logger

  # def try_tag_thing(user, thing, attrs) do
  #   IO.inspect(attrs)
  # end

  @doc """
  lookup tag from URL(s), to support vf-graphql mode
  """

  # def try_tag_thing(_user, thing, %{resource_classified_as: urls})
  #     when is_list(urls) and length(urls) > 0 do
  #   # todo: lookup tag by URL
  #   {:ok, thing}
  # end

  def map_values(%{} = map, func) do
    for {k, v} <- map, into: %{}, do: {k, func.(v)}
  end

  def try_tag_thing(user, thing, tags) do
    if module_enabled?(Bonfire.Tag.Tags) do
      Bonfire.Tag.Tags.maybe_tag(user, thing, tags)
    else
      {:ok, thing}
    end
  end


  def publish(%{id: creator_id} =creator, verb, %{id: thing_id} =thing) do

    if module_enabled?(Bonfire.Me.Users.Boundaries), do: Bonfire.Me.Users.Boundaries.maybe_make_visible_for(creator, thing, [:guest])

    ValueFlows.Util.Federation.ap_publish("create", thing_id, creator_id)

    if module_enabled?(Bonfire.Social.FeedActivities) and Kernel.function_exported?(Bonfire.Social.FeedActivities, :publish, 3) do

      Bonfire.Social.FeedActivities.publish(creator, verb, thing)

    else
      Logger.info("No integration available to publish activity")
      {:ok, nil}
    end

  end

  def publish(%{creator_id: creator_id, id: thing_id}, :update) do
    # TODO: wrong if edited by admin
    ValueFlows.Util.Federation.ap_publish("update", thing_id, creator_id)
  end

  def publish(%{creator_id: creator_id, id: thing_id}, :delete) do
    # TODO: wrong if edited by admin
    ValueFlows.Util.Federation.ap_publish("delete", thing_id, creator_id)
  end

  def publish(%{creator_id: creator_id, id: thing_id}, :deleted) do # deprecate
    publish(%{creator_id: creator_id, id: thing_id}, :delete)
  end

  def publish(_, verb) do
    Logger.warn("Could not publish (#{verb})")
    :ok
  end

  def index_for_search(object) do
    if module_enabled?(Bonfire.Search.Indexer) do
      Bonfire.Search.Indexer.maybe_index_object(object)
    else
      :ok
    end
  end

  def indexing_format_creator(obj) do
    if module_enabled?(Bonfire.Search.Indexer),
      do: Bonfire.Search.Indexer.format_creator(obj)
  end

  def indexing_format_tags(obj) do
    if module_enabled?(Bonfire.Tag.Tags) do
      repo().maybe_preload(obj, tags: [:profile])
      |> Map.get(:tags, [])
      |> Enum.map(&Bonfire.Tag.Tags.indexing_object_format_name/1)
    end
  end

  def image_url(%{icon_id: icon_id} = thing) when not is_nil(icon_id) do
    Bonfire.Common.Utils.avatar_url(thing)
  end

  def image_url(%{image_id: image_id} = thing) when not is_nil(image_id) do
    Bonfire.Common.Utils.image_url(thing)
  end

  # def image_url(%{icon_id: icon_id} = thing) when not is_nil(icon_id) do
  #   Bonfire.Repo.maybe_preload(thing, icon: [:content_upload, :content_mirror])
  #   # |> IO.inspect()
  #   |> Map.get(:icon)
  #   |> content_url_or_path()
  # end

  # def image_url(%{image_id: image_id} = thing) when not is_nil(image_id) do
  #   #IO.inspect(thing)
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

  def user_schema() do
    Bonfire.Common.Extend.maybe_schema_or_pointer(@user)
  end

  def is_admin(user) do
    if Map.get(user, :instance_admin) do
      Map.get(user.instance_admin, :is_instance_admin)
    else
      false # FIXME
    end
  end

  def image_schema() do
    Bonfire.Common.Extend.maybe_schema_or_pointer(@image_schema)
  end
end
