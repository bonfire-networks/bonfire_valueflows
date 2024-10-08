# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Agent.Agents do
  # alias ValueFlows.{Simulate}
  import Untangle
  use Bonfire.Common.Utils
  import Bonfire.Common.Config, only: [repo: 0]

  # TODO - change approach to allow pagination
  def agents(signed_in_user) do
    orgs = ValueFlows.Agent.Organizations.organizations(signed_in_user)
    people = ValueFlows.Agent.People.people(signed_in_user)

    orgs ++ people
  end

  # FIXME - this works but isn't elegant
  def agent(id, signed_in_user) do
    case ValueFlows.Agent.People.person(id, signed_in_user) do
      {:error, _error} ->
        ValueFlows.Agent.Organizations.organization(id, signed_in_user)

      org ->
        org
    end
  end

  def agent_to_character(a) do
    a
    |> Enums.maybe_put(:summary, Map.get(a, :note))
    |> Enums.maybe_put(:geolocation, Map.get(a, :primary_location))
  end

  def character_to_agent(a) do
    # a = Bonfire.Common.Repo.maybe_preload(a, [icon: [:content], image: [:content]])

    a
    |> repo().maybe_preload(:shared_user, label: __MODULE__)
    # |> IO.inspect()
    |> Enums.merge_structs_as_map(
      e(a, :profile, %{
        name: e(a, :character, :username, "anonymous")
      })
    )
    |> Enums.merge_structs_as_map(e(a, :character, %{}))
    |> Map.put(:image, ValueFlows.Util.image_url(a))
    |> Enums.maybe_put(:primary_location, agent_location(a))
    |> Enums.maybe_put(:note, e(a, :profile, :summary, nil))
    # |> Enums.maybe_put(:display_username, ValueFlows.Util.display_username(a))
    |> add_type()
    |> debug()
  end

  def agent_location(%{profile_id: profile_id} = a)
      when not is_nil(profile_id) do
    repo().maybe_preload(a, profile: [:geolocation])
    |> Map.get(:profile)
    |> agent_location()
  end

  def agent_location(%{geolocation_id: geolocation_id} = a)
      when not is_nil(geolocation_id) do
    repo().maybe_preload(a, :geolocation)
    |> Map.get(:geolocation)
  end

  def agent_location(_) do
    nil
  end

  # def add_type(%ValueFlows.Util.user_schema(){} = a) do
  #   a
  #   |> Map.put(:agent_type, :person)
  # end

  # def add_type(%ValueFlows.Util.org_schema(){} = a) do
  #   a
  #   |> Map.put(:agent_type, :organization)
  # end

  def add_type(a) do
    user_type = ValueFlows.Util.user_schema()
    org_type = ValueFlows.Util.org_schema()

    case a do
      # for SharedUser within a User
      %{shared_user: %{id: _}} ->
        Map.put(a, :agent_type, :organization)

      %{__struct__: user_type} ->
        Map.put(a, :agent_type, :person)

      %{__typename: user_type} ->
        Map.put(a, :agent_type, :person)

      %{__struct__: org_type} ->
        Map.put(a, :agent_type, :organization)

      _ ->
        Map.put(a, :agent_type, :person)
    end
  end

  def add_type(a) do
    Map.put(a, :agent_type, :person)
  end
end
