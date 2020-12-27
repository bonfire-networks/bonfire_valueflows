# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Agent.People do
  # alias ValueFlows.{Simulate}
  require Logger

  def people(signed_in_user) do
    people = if Bonfire.Common.Utils.module_exists?(Bonfire.Me.Identity.Users) do
         Bonfire.Me.Identity.Users.list()
    else
      if Bonfire.Common.Utils.module_exists?(CommonsPub.Users) do
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
    person = if Bonfire.Common.Utils.module_exists?(Bonfire.Me.Identity.Users) do
         with {:ok, user} =
              Bonfire.Me.Identity.Users.by_id(id) do
          user
        end
    else
      if Bonfire.Common.Utils.module_exists?(CommonsPub.Users) do
        with {:ok, user} =
              CommonsPub.Users.one([:default, :geolocation, id: id, user: signed_in_user]) do
          user
        end
      end
    end

    ValueFlows.Agent.Agents.character_to_agent(person || %{})
  end

end
