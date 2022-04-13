# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Agent.People do
  # alias ValueFlows.{Simulate}
  import Where

  def people(signed_in_user) do
    if Bonfire.Common.Extend.module_enabled?(Bonfire.Me.Users) do
         Bonfire.Me.Users.list() |> format()
    else
      if Bonfire.Common.Extend.module_enabled?(CommonsPub.Users) do
        {:ok, users} = CommonsPub.Users.many([:default, user: signed_in_user])
        format(users)
      else
        error("people feature not implemented")
        []
      end
    end

  end

  defp format(people) when is_list(people), do: Enum.map(people, &format/1) |> Enum.reject(fn
      %{agent_type: :organization} -> true
      _ -> false
    end)

  defp format(person) do
    person
    |> ValueFlows.Agent.Agents.character_to_agent()
  end

  def person(id, current_user) when is_binary(id) do
    if Bonfire.Common.Extend.module_enabled?(Bonfire.Me.Users) do
         with {:ok, person} <- Bonfire.Me.Users.by_id(id, current_user: current_user) do
          format(person)
         else _ ->
          nil
        end
    else
      if Bonfire.Common.Extend.module_enabled?(CommonsPub.Users) do
        with {:ok, person} <-
              CommonsPub.Users.one([:default, :geolocation, id: id, user: current_user]) do
          format(person)
        else _ ->
          nil
        end
      else
        error("people feature not implemented")
        nil
      end
    end
  end

  def person(_, _), do: nil

end
