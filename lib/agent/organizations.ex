# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Agent.Organizations do
  # alias ValueFlows.Simulate
  import Untangle
  import Bonfire.Common.Config, only: [repo: 0]

  def organizations(signed_in_user) do
    if Bonfire.Common.Extend.module_enabled?(Organisation.Organisations) do
      with {:ok, orgs} = Organisation.Organisations.many([:default, user: signed_in_user]) do
        format(orgs)
      end
    else
      if Bonfire.Common.Extend.module_enabled?(Bonfire.Me.Users) do
        Bonfire.Me.Users.list(signed_in_user) |> format()
      else
        error("organizations feature not implemented")
        []
      end
    end
  end

  defp format(orgs) when is_list(orgs),
    do:
      orgs
      |> repo().maybe_preload(:shared_user, label: __MODULE__)
      |> Enum.map(&format/1)
      |> Enum.reject(fn
        %{agent_type: :person} -> true
        _ -> false
      end)

  defp format(org) do
    ValueFlows.Agent.Agents.character_to_agent(org)
  end

  def organization(id, current_user) do
    if Bonfire.Common.Extend.module_enabled?(Organisation.Organisations) do
      with {:ok, org} =
             Organisation.Organisations.one([
               :default,
               id: id,
               user: current_user
             ]) do
        format(org)
      end
    else
      if Bonfire.Common.Extend.module_enabled?(Bonfire.Me.Users) do
        with {:ok, org} <-
               Bonfire.Me.Users.by_id(id, current_user: current_user) do
          format(org)
        else
          _ ->
            nil
        end
      else
        error("organizations feature not implemented")
        %{}
      end
    end
  end
end
