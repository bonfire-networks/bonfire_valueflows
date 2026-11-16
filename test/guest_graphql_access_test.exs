defmodule ValueFlows.GuestGraphQLAccessTest do
  @moduledoc "Over GraphQL a guest may read what the web UI shows guests (processes and tasks), and nothing else of ValueFlows: the other root queries ask for a login."
  use Bonfire.ValueFlows.DataCase, async: true

  import ValueFlows.Simulate

  @schema Bonfire.API.GraphQL.Schema

  defp guest_run(query, variables \\ %{}),
    do: Absinthe.run(query, @schema, variables: variables, context: %{})

  defp needs_login?({:ok, %{errors: errors}}),
    do:
      Enum.any?(
        errors,
        &(to_string(&1[:message]) =~ ~r/log ?in/i or &1[:code] in ["needs_login", :needs_login])
      )

  defp needs_login?(_), do: false

  test "a guest can query a process and the list of processes" do
    user = fake_agent!()
    process = fake_process!(user)

    refute needs_login?(
             guest_run("query($id: ID!) { process(id: $id) { id } }", %{"id" => process.id})
           )

    refute needs_login?(guest_run("{ processesPages { edges { id } } }"))
  end

  test "a guest can query a task (intent), the list of tasks, offers and needs" do
    user = fake_agent!()
    intent = fake_intent!(user)

    refute needs_login?(
             guest_run("query($id: ID!) { intent(id: $id) { id } }", %{"id" => intent.id})
           )

    refute needs_login?(guest_run("{ intentsPages { edges { id } } }"))
    refute needs_login?(guest_run("{ offersPages { edges { id } } }"))
    refute needs_login?(guest_run("{ needsPages { edges { id } } }"))
  end

  test "control: other ValueFlows queries still ask a guest to log in" do
    user = fake_agent!()
    spec = fake_process_specification!(user)

    assert needs_login?(
             guest_run("query($id: ID!) { processSpecification(id: $id) { id } }", %{
               "id" => spec.id
             })
           )
  end
end
