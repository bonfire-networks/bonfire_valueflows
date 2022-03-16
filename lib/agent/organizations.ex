# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Agent.Organizations do
  # alias ValueFlows.Simulate
  import Where

  def organizations(signed_in_user) do
    if Bonfire.Common.Extend.module_enabled?(Organisation.Organisations) do
      with {:ok, orgs} = Organisation.Organisations.many([:default, user: signed_in_user]) do
        format(orgs)
      end
    else
      if Bonfire.Common.Extend.module_enabled?(Bonfire.Me.Users) do
         Bonfire.Me.Users.list() |> format()
      else
        error("organizations feature not implemented")
        []
      end
    end
  end

  defp format(orgs) when is_list(orgs), do: Enum.map(orgs, &format/1) |> Enum.reject(fn
      %{agent_type: :person} -> true
      _ -> false
    end)

  defp format(org) do
    org
    |> ValueFlows.Agent.Agents.character_to_agent()
  end

  def organization(id, signed_in_user) do
    if Bonfire.Common.Extend.module_enabled?(Organisation.Organisations) do
      with {:ok, org} = Organisation.Organisations.one([:default, id: id, user: signed_in_user]) do
        format(org)
      end
    else
      if Bonfire.Common.Extend.module_enabled?(Bonfire.Me.Users) do
         with {:ok, org} <- Bonfire.Me.Users.by_id(id) do
          format(org)
         else _ ->
          nil
        end
      else
        error("organizations feature not implemented")
        %{}
      end
    end
  end
end
