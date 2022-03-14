defmodule ValueFlows.TrackAndTraceGraphQLTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  # import Bonfire.Common.Simulation

  import ValueFlows.Simulate

  # import Bonfire.Geolocate.Simulate

  # import ValueFlows.Test.Faking

  # alias ValueFlows.EconomicEvent.EconomicEvents
  # alias ValueFlows.EconomicResource.EconomicResources

  @schema Bonfire.API.GraphQL.Schema

  describe "Trace" do
    test "3 level nesting" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      resource = fake_economic_resource!(user, %{}, unit)
      other_resource = fake_economic_resource!(user, %{}, unit)

      process = fake_process!(user)

      output_event = fake_economic_event!(user, %{
        output_of: process.id,
        resource_inventoried_as: resource.id,
        action: "produce"
      }, unit)

      input_event = fake_economic_event!(user, %{
        input_of: process.id,
        resource_inventoried_as: other_resource.id,
        action: "use"
      }, unit)

      query = """
        query ($id: ID) {
        economicResource(id: $id) {
          id
          trace {
            __typename
            ... on EconomicEvent {
              id
              trace {
                __typename
                ... on EconomicEvent {
                  id
                }
                ... on Process {
                  id
                  trace {
                    __typename
                    ... on EconomicEvent {
                      trace {
                        __typename
                      }
                    }
                  }
                }
                ... on EconomicResource {
                  id
                  trace {
                    __typename
                    ... on EconomicEvent {
                      trace {
                        __typename
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      """

      q = Absinthe.run(query, @schema, variables: %{"id" => resource.id})
      # IO.inspect(q: q)
      assert {:ok, %{data: result}} = q
      assert result["economicResource"]["id"] == resource.id
      assert hd(result["economicResource"]["trace"])["id"] == output_event.id
      assert hd(hd(result["economicResource"]["trace"])["trace"])["id"] == process.id
      assert hd(hd(hd(result["economicResource"]["trace"])["trace"])["trace"])["id"] == input_event.id
      assert hd(hd(hd(hd(result["economicResource"]["trace"])["trace"])["trace"])["trace"])["__typename"] == "EconomicResource"
    end
  end

  describe "Track" do
    test "3 level nesting" do
      user = fake_agent!()
      unit = maybe_fake_unit(user)

      resource = fake_economic_resource!(user, %{}, unit)
      other_resource = fake_economic_resource!(user, %{}, unit)

      process = fake_process!(user)

      output_event = fake_economic_event!(user, %{
        output_of: process.id,
        resource_inventoried_as: resource.id,
        action: "produce"
      }, unit)

      input_event = fake_economic_event!(user, %{
        input_of: process.id,
        resource_inventoried_as: other_resource.id,
        action: "use"
      }, unit)

      query = """
        query ($id: ID) {
        economicResource(id: $id) {
          id
          track {
            __typename
            ... on EconomicResource {
              id
            }
            ... on EconomicEvent {
              id
              track {
                __typename
                ... on EconomicEvent {
                  id
                }
                ... on Process {
                  id
                  track {
                    __typename
                    ... on EconomicEvent {
                      track {
                        __typename
                      }
                    }
                  }
                }
                ... on EconomicResource {
                  id
                  track {
                    __typename
                    ... on EconomicEvent {
                      track {
                        __typename
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      """

      q = Absinthe.run(query, @schema, variables: %{"id" => other_resource.id})
      # IO.inspect(q: q)
      assert {:ok, %{data: result}} = q

      assert result["economicResource"]["id"] == other_resource.id
      assert hd(result["economicResource"]["track"])["id"] == input_event.id
      assert hd(hd(result["economicResource"]["track"])["track"])["id"] == process.id
      assert hd(hd(hd(result["economicResource"]["track"])["track"])["track"])["id"] == output_event.id
      assert hd(hd(hd(hd(result["economicResource"]["track"])["track"])["track"])["track"])["__typename"] == "EconomicResource"
    end
  end

end
