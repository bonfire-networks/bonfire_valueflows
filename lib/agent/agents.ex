# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Agent.Agents do
  # alias ValueFlows.{Simulate}
  require Logger
  import Bonfire.Common.Utils, only: [maybe_put: 3]

  @user Bonfire.Common.Config.get!(:user_schema)
  @org_schema Bonfire.Common.Config.get!(:org_schema)

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
    |> Map.merge(Map.get(a, :profile, %{}))
    |> Map.merge(Map.get(a, :character, %{}))

    a
    |> Map.put(:image, ValueFlows.Util.image_url(a))
    |> maybe_put(:primary_location, agent_location(a))
    |> maybe_put(:note, Map.get(a, :summary))
    # |> maybe_put(:display_username, ValueFlows.Util.display_username(a))
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

  def add_type(%@user{} = a) do
    a
    |> Map.put(:agent_type, :person)
  end

  def add_type(%@org_schema{} = a) do
    a
    |> Map.put(:agent_type, :organization)
  end

  def add_type(a) do
    a
    |> Map.put(:agent_type, :person)
  end
end
