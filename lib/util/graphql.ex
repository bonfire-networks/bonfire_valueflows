# SPDX-License-Identifier: AGPL-3.0-only
if Code.ensure_loaded?(Bonfire.GraphQL) do
defmodule ValueFlows.Util.GraphQL do
  import Bonfire.Common.Config, only: [repo: 0]
  alias Bonfire.GraphQL

  require Logger

  # use Absinthe.Schema.Notation
  # import_sdl path: "lib/value_flows/graphql/schemas/util.gql"

  # object :page_info do
  #   field :start_cursor, list_of(non_null(:cursor))
  #   field :end_cursor, list_of(non_null(:cursor))
  #   field :has_previous_page, non_null(:boolean)
  #   field :has_next_page, non_null(:boolean)
  # end

  def parse_cool_scalar(value), do: {:ok, value}
  def serialize_cool_scalar(%{value: value}), do: value
  def serialize_cool_scalar(value), do: value

  def scope_edge(%{in_scope_of: ids}, page_opts, info),
    do: Bonfire.GraphQL.CommonResolver.context_edges(%{context_ids: ids}, page_opts, info)

  def scope_edge(%{context_id: id}, page_opts, info),
    do: scope_edge(%{in_scope_of: [id]}, page_opts, info)

  def scope_edge(_, _, _),
    do: {:ok, nil}

  def fetch_provider_edge(%{provider_id: id}, _, info) when not is_nil(id) do
    {:ok, ValueFlows.Agent.Agents.agent(id, GraphQL.current_user(info))}
  end

  def fetch_provider_edge(_, _, _) do
    {:ok, nil}
  end

  def fetch_receiver_edge(%{receiver_id: id}, _, info) when not is_nil(id) do
    {:ok, ValueFlows.Agent.Agents.agent(id, GraphQL.current_user(info))}
  end

  def fetch_receiver_edge(_, _, _) do
    {:ok, nil}
  end

  def fetch_classifications_edge(%{tags: _tags} = thing, _, _) do
    thing = repo().preload(thing, tags: :character)
    urls = Enum.map(thing.tags, & &1.character.canonical_url)
    {:ok, urls}
  end

  def fetch_classifications_edge(_, _, _) do
    {:ok, nil}
  end

  def current_location_edge(%{current_location_id: id} = thing, _, _) when not is_nil(id) do
    thing = repo().preload(thing, :current_location)

    {:ok,
     Bonfire.Geolocate.Geolocations.populate_coordinates(Map.get(thing, :current_location, nil))}
  end

  def current_location_edge(_, _, _) do
    {:ok, nil}
  end

  def at_location_edge(%{at_location_id: id} = thing, _, _) when not is_nil(id) do
    thing = repo().preload(thing, :at_location)
    {:ok, Bonfire.Geolocate.Geolocations.populate_coordinates(Map.get(thing, :at_location, nil))}
  end

  def at_location_edge(_, _, _) do
    {:ok, nil}
  end

  def fetch_resource_conforms_to_edge(%{resource_conforms_to_id: id} = thing, _, _)
      when is_binary(id) do
    thing = repo().preload(thing, :resource_conforms_to)
    {:ok, Map.get(thing, :resource_conforms_to)}
  end

  def fetch_resource_conforms_to_edge(_, _, _) do
    {:ok, nil}
  end

  def available_quantity_edge(%{available_quantity_id: id} = thing, _, _) when not is_nil(id) do
    thing = repo().preload(thing, available_quantity: [:unit])
    {:ok, Map.get(thing, :available_quantity)}
  end

  def available_quantity_edge(_, _, _) do
    {:ok, nil}
  end

  def resource_quantity_edge(%{resource_quantity_id: id} = thing, _, _) when not is_nil(id) do
    thing = repo().preload(thing, resource_quantity: [:unit])
    {:ok, Map.get(thing, :resource_quantity)}
  end

  def resource_quantity_edge(_, _, _) do
    {:ok, nil}
  end

  def effort_quantity_edge(%{effort_quantity_id: id} = thing, _, _) when not is_nil(id) do
    thing = repo().preload(thing, effort_quantity: [:unit])
    {:ok, Map.get(thing, :effort_quantity)}
  end

  def effort_quantity_edge(_, _, _) do
    {:ok, nil}
  end

  def accounting_quantity_edge(%{accounting_quantity_id: id} = thing, _, _) when not is_nil(id) do
    thing = repo().preload(thing, accounting_quantity: [:unit])
    {:ok, Map.get(thing, :accounting_quantity)}
  end

  def accounting_quantity_edge(_, _, _) do
    {:ok, nil}
  end

  def onhand_quantity_edge(%{onhand_quantity_id: id} = thing, _, _) when not is_nil(id) do
    thing = repo().preload(thing, onhand_quantity: [:unit])
    {:ok, Map.get(thing, :onhand_quantity)}
  end

  def onhand_quantity_edge(_, _, _), do: {:ok, nil}

  def image_content_url(%{image_id: id} = thing, _, _info) when not is_nil(id) do
    {:ok, ValueFlows.Util.image_url(thing)}
  end

  def image_content_url(_, _, _), do: {:ok, nil}

  def maybe_upload(user, changes, info) do
    if Bonfire.Common.Utils.module_exists?(CommonsPub.Web.GraphQL.UploadResolver) do
      CommonsPub.Web.GraphQL.UploadResolver.upload(user, changes, info)
    else
      Logger.info("Could not upload")
      {:ok, %{}}
    end
  end

  def tags_edges(a, b, c) do
    if Bonfire.Common.Utils.module_exists?(Bonfire.Tag.GraphQL.TagResolver) do
      Bonfire.Tag.GraphQL.TagResolver.tags_edges(a, b, c)
    else
      Logger.warn("Could not resolve tags")
      {:ok, nil}
    end
  end
end
end
