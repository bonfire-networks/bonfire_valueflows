# SPDX-License-Identifier: AGPL-3.0-only
if Code.ensure_loaded?(Bonfire.GraphQL) do
defmodule ValueFlows.Agent.GraphQL do
  alias Bonfire.GraphQL

  require Logger

  # use Absinthe.Schema.Notation
  # import_sdl path: "lib/value_flows/graphql/schemas/agent.gql"

  # fake data
  # def all_agents(_, _) do
  #   {:ok, long_list(&Simulate.agent/0)}
  # end

  # def agent(%{id: id}, info) do
  #   {:ok, Simulate.agent()}
  # end

  # proper resolvers

  # with pagination
  def people(page_opts, info) do
    people_pages =
      if Bonfire.Common.Utils.module_enabled?(CommonsPub.Web.GraphQL.UsersResolver) do
        with {:ok, users_pages} <- CommonsPub.Web.GraphQL.UsersResolver.users(page_opts, info) do
          people =
            Enum.map(
              users_pages.edges,
              &(&1
                |> ValueFlows.Agent.Agents.character_to_agent())
            )

          %{ users_pages | edges: people}

        end
      else
        people = ValueFlows.Agent.People.people(nil)
        |> Enum.map(
            &(&1
              |> ValueFlows.Agent.Agents.character_to_agent())
          )

        %{
          edges: people,
          page_info: nil,
          total_count: length(people)
        }
    end

    {:ok, people_pages}
  end

  # TODO: pagination
  def all_people(%{}, info) do
    {:ok, ValueFlows.Agent.People.people(Bonfire.GraphQL.current_user(info))}
  end

  def person(%{id: id}, info) do
    {:ok, ValueFlows.Agent.People.person(id, Bonfire.GraphQL.current_user(info))}
  end

  # with pagination
  def organizations(page_opts, info) do
    orgz_pages =
      if Bonfire.Common.Utils.module_enabled?(Organisation.GraphQL.Resolver) do
        with {:ok, pages} <- Organisation.GraphQL.Resolver.organisations(page_opts, info) do
          orgz =
            Enum.map(
              pages.edges,
              &(&1
                |> ValueFlows.Agent.Agents.character_to_agent())
            )

          %{ pages | edges: orgz}

        end
      else
        %{}
      end

    {:ok, orgz_pages}
  end

  # without pagination
  def all_organizations(%{}, info) do
    {:ok, ValueFlows.Agent.Organizations.organizations(Bonfire.GraphQL.current_user(info))}
  end

  def organization(%{id: id}, info) do
    {:ok,
     ValueFlows.Agent.Organizations.organization(
       id,
       Bonfire.GraphQL.current_user(info)
     )}
  end

  def all_agents(%{}, info) do
    {:ok, ValueFlows.Agent.Agents.agents(Bonfire.GraphQL.current_user(info))}
  end

  def agent(%{id: id}, info) do
    {:ok, ValueFlows.Agent.Agents.agent(id, Bonfire.GraphQL.current_user(info))}
  end

  def my_agent(_, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info) do
      {:ok, user |> ValueFlows.Agent.Agents.character_to_agent()}
    end
  end

  def mutate_person(_, _) do
    {:error, "Please use one of these instead: createUser, updateProfile, deleteSelf"}
  end

  def mutate_organization(_, _) do
    {:error,
     "Please use one of these instead (notice the spelling difference): createOrganisation, updateOrganisation, delete"}
  end
end
end
