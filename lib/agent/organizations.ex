# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Agent.Organizations do
  # alias ValueFlows.Simulate
  require Logger

  def organizations(signed_in_user) do
    if Code.ensure_loaded?(Organisation.Organisations) do
      with {:ok, orgs} = Organisation.Organisations.many([:default, user: signed_in_user]) do
        Enum.map(
          orgs,
          &(&1
            |> ValueFlows.Agent.Agents.character_to_agent())
        )
      end
    else
      []
    end
  end

  def organization(id, signed_in_user) do
    if Code.ensure_loaded?(Organisation.Organisations) do
      with {:ok, org} = Organisation.Organisations.one([:default, id: id, user: signed_in_user]) do
        ValueFlows.Agent.Agents.character_to_agent(org)
      end
    else
      %{}
    end
  end
end
