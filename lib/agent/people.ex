# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Agent.People do
  # alias ValueFlows.{Simulate}
  require Logger

  def people(signed_in_user) do
    people = if Code.ensure_loaded?(Bonfire.Me.Identity.Users) do
         Bonfire.Me.Identity.Users.list()
    else
      if Code.ensure_loaded?(CommonsPub.Users) do
        {:ok, users} = CommonsPub.Users.many([:default, user: signed_in_user])
        users
      else
        []
      end
    end

    Enum.map(
      people,
      &(&1
        |> ValueFlows.Agent.Agents.character_to_agent())
    )

  end

  def person(id, signed_in_user) do
    if Code.ensure_loaded?(CommonsPub.Users) do
      with {:ok, user} =
             CommonsPub.Users.one([:default, :geolocation, id: id, user: signed_in_user]) do
        ValueFlows.Agent.Agents.character_to_agent(user)
      end
    else
      %{}
    end
  end
end
