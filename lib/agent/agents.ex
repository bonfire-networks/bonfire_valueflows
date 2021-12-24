# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Agent.Agents do
  # alias ValueFlows.{Simulate}
  require Logger
  import Bonfire.Common.Utils, only: [maybe_put: 3, merge_structs_as_map: 2]
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
    |> maybe_put(:summary, Map.get(a, :note))
    |> maybe_put(:geolocation, Map.get(a, :primary_location))
  end

  def character_to_agent(a) do
    # a = Bonfire.Repo.maybe_preload(a, [icon: [:content], image: [:content]])

    a = a
    |> repo().maybe_preload(:shared_user)
    # |> IO.inspect()
    |> merge_structs_as_map(Map.get(a, :profile, %{}))
    |> merge_structs_as_map(Map.get(a, :character, %{}))

    a
    |> Map.put(:image, ValueFlows.Util.image_url(a))
    |> maybe_put(:primary_location, agent_location(a))
    |> maybe_put(:note, Map.get(a, :summary))
    # |> maybe_put(:display_username, ValueFlows.Util.display_username(a))
    # |> IO.inspect()
    |> add_type()
    # |> IO.inspect()
  end

  def agent_location(%{profile_id: profile_id} = a) when not is_nil(profile_id) do
    Bonfire.Repo.maybe_preload(a, profile: [:geolocation])
    |> Map.get(:profile)
    |> agent_location()
  end

  def agent_location(%{geolocation_id: geolocation_id} = a) when not is_nil(geolocation_id) do
    Bonfire.Repo.maybe_preload(a, :geolocation)
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
      %{shared_user: %{id: _}} -> # for SharedUser within a User
        a
        |> Map.put(:agent_type, :organization)
      %{__struct__: user_type} ->
        a
        |> Map.put(:agent_type, :person)
      %{__typename: user_type} ->
        a
        |> Map.put(:agent_type, :person)
      %{__struct__: org_type} ->
        a
        |> Map.put(:agent_type, :organization)
      _ ->
        a
        |> Map.put(:agent_type, :person)
    end
  end

  def add_type(a) do
     a
        |> Map.put(:agent_type, :person)
  end
end
