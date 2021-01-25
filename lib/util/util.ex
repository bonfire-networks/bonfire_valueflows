# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Util do
  import Bonfire.Common.Utils
  import Bonfire.Common.Config, only: [repo: 0]
  @user Bonfire.Common.Config.get!(:user_schema)
  @image_schema CommonsPub.Uploads.Content

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

  def try_tag_thing(user, thing, tags) do
    if module_exists?(Bonfire.Tag.Tags) do
      Bonfire.Tag.Tags.maybe_tag(user, thing, tags)
    else
      {:ok, thing}
    end
  end

  def activity_create(creator, item, act_attrs) do
    if module_exists?(CommonsPub.Activities) do
      CommonsPub.Activities.create(creator, item, act_attrs)
    else
      {:ok, nil}
    end
  end

  def publish(creator, thing, activity, :created) do
    feeds =
      if module_exists?(CommonsPub.Feeds) do
        [
          CommonsPub.Feeds.outbox_id(creator),
          CommonsPub.Feeds.instance_outbox_id()
        ]
      end

    do_publish_create(creator, thing, activity, feeds)
  end

  def publish(creator, %{outbox_id: context_outbox_id} = _context, thing, activity, :created) do
    publish(creator, context_outbox_id, thing, activity, :created)
  end

  def publish(creator, %{character: _context_character} = context, thing, activity, :created) do
    repo().maybe_preload(context, :character)
    publish(creator, Map.get(context, :character), thing, activity, :created)
  end

  def publish(creator, context_outbox_id, thing, activity, :created)
      when is_binary(context_outbox_id) do
    feeds =
      if module_exists?(CommonsPub.Feeds) do
        [
          context_outbox_id,
          CommonsPub.Feeds.outbox_id(creator),
          CommonsPub.Feeds.instance_outbox_id()
        ]
      end

    do_publish_create(creator, thing, activity, feeds)
  end

  def publish(creator, _, thing, activity, verb),
    do: publish(creator, thing, activity, verb)

  defp do_publish_create(%{id: creator_id}, %{id: thing_id}, activity, feeds) do
    do_publish_feed_activity(activity, feeds)

    ValueFlows.Util.Federation.ap_publish("create", thing_id, creator_id)
  end

  defp do_publish_create(_, _, activity, feeds) do
    do_publish_feed_activity(activity, feeds)
  end

  defp do_publish_feed_activity(activity, feeds) do
    if module_exists?(CommonsPub.Feeds.FeedActivities) and !is_nil(activity) and is_list(feeds) and
         length(feeds) > 0 and Kernel.function_exported?(CommonsPub.Feeds.FeedActivities, :publish, 2) do
      CommonsPub.Feeds.FeedActivities.publish(activity, feeds)
    else
      Logger.info("Could not publish activity")
    end

    :ok
  end

  def publish(%{creator_id: creator_id, id: thing_id}, :updated) do
    # TODO: wrong if edited by admin
    ValueFlows.Util.Federation.ap_publish("update", thing_id, creator_id)
  end

  def publish(%{creator_id: creator_id, id: thing_id}, :deleted) do
    # TODO: wrong if edited by admin
    ValueFlows.Util.Federation.ap_publish("delete", thing_id, creator_id)
  end

  def publish(_, verb) do
    Logger.warn("Could not publish (#{verb})")
    :ok
  end

  def index_for_search(object) do
    if module_exists?(Bonfire.Search.Indexer) do
      Bonfire.Search.Indexer.maybe_index_object(object)
    end

    :ok
  end

  def indexing_format_creator(obj) do
    if module_exists?(Bonfire.Search.Indexer),
      do: Bonfire.Search.Indexer.format_creator(obj)
  end


  def image_url(%{icon_id: icon_id} = thing) when not is_nil(icon_id) do
    Bonfire.Repo.maybe_preload(thing, icon: [:content_upload, :content_mirror])
    # |> IO.inspect()
    |> Map.get(:icon)
    |> content_url_or_path()
  end

  def image_url(%{image_id: image_id} = thing) when not is_nil(image_id) do
    # IO.inspect(thing)
    Bonfire.Repo.maybe_preload(thing, image: [:content_upload, :content_mirror])
    |> Map.get(:image)
    |> content_url_or_path()
  end

  def image_url(%{profile: _} = thing) do
    Bonfire.Repo.maybe_preload(thing, profile: [image: [:content_upload, :content_mirror], icon: [:content_upload, :content_mirror]])
    |> Map.get(:profile)
    |> image_url()
  end

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
    Bonfire.Common.Config.maybe_schema_or_pointer(@user)
  end

  def is_admin(user) do
    if Map.get(user, :local_user) do
      Map.get(user.local_user, :is_instance_admin)
    else
      false # FIXME
    end
  end

  def image_schema() do
    Bonfire.Common.Config.maybe_schema_or_pointer(@image_schema)
  end
end
