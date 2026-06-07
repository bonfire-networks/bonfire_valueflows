# SPDX-License-Identifier: AGPL-3.0-only
if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule ValueFlows.Util.GraphQL do
    import Bonfire.Common.Config, only: [repo: 0]
    alias Bonfire.API.GraphQL
    use Bonfire.Common.Utils

    import Untangle

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
      thing = repo().maybe_preload(thing, tags: [:peered])

      urls =
        e(thing, :tags, [])
        |> Enum.map(&Bonfire.Common.URIs.canonical_url(&1))

      {:ok, urls}
    end

    def fetch_classifications_edge(_, _, _) do
      {:ok, nil}
    end

    def fetch_resource_conforms_to_edge(
          %{resource_conforms_to_id: id} = thing,
          _,
          _
        )
        when is_binary(id) do
      thing = repo().preload(thing, :resource_conforms_to)
      {:ok, Map.get(thing, :resource_conforms_to)}
    end

    def fetch_resource_conforms_to_edge(_, _, _) do
      {:ok, nil}
    end

    def available_quantity_edge(%{available_quantity_id: id} = thing, _, _)
        when not is_nil(id) do
      thing = repo().preload(thing, available_quantity: [:unit])
      {:ok, Map.get(thing, :available_quantity)}
    end

    def available_quantity_edge(_, _, _) do
      {:ok, nil}
    end

    def resource_quantity_edge(%{resource_quantity_id: id} = thing, _, _)
        when not is_nil(id) do
      thing = repo().preload(thing, resource_quantity: [:unit])
      {:ok, Map.get(thing, :resource_quantity)}
    end

    def resource_quantity_edge(_, _, _) do
      {:ok, nil}
    end

    def effort_quantity_edge(%{effort_quantity_id: id} = thing, _, _)
        when not is_nil(id) do
      thing = repo().preload(thing, effort_quantity: [:unit])
      {:ok, Map.get(thing, :effort_quantity)}
    end

    def effort_quantity_edge(_, _, _) do
      {:ok, nil}
    end

    def accounting_quantity_edge(%{accounting_quantity_id: id} = thing, _, _)
        when not is_nil(id) do
      thing = repo().preload(thing, accounting_quantity: [:unit])
      {:ok, Map.get(thing, :accounting_quantity)}
    end

    def accounting_quantity_edge(_, _, _) do
      {:ok, nil}
    end

    def onhand_quantity_edge(%{onhand_quantity_id: id} = thing, _, _)
        when not is_nil(id) do
      thing = repo().preload(thing, onhand_quantity: [:unit])
      {:ok, Map.get(thing, :onhand_quantity)}
    end

    def onhand_quantity_edge(_, _, _), do: {:ok, nil}

    def image_content_url(%{image_id: id} = thing, _, _info)
        when not is_nil(id) do
      {:ok, ValueFlows.Util.image_url(thing)}
    end

    def image_content_url(_, _, _), do: {:ok, nil}
  end
end
