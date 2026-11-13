defmodule ValueFlows.Planning.IntentTimeSpanTest do
  # an Intent's `has_beginning` now lives in the `Bonfire.Data.Time.TimeSpan` mixin, and Intent reads and writes it through the `vf_intent_view` view
  use Bonfire.ValueFlows.DataCase, async: true

  import ValueFlows.Simulate

  alias Bonfire.Common.Repo
  alias Bonfire.Data.Time.TimeSpan
  alias ValueFlows.Planning.Intent
  alias ValueFlows.Planning.Intent.Intents

  @begin_a ~U[2030-01-01 10:00:00.000000Z]
  @begin_b ~U[2031-02-02 12:30:00.000000Z]
  @begin_c ~U[2032-03-03 08:15:00.000000Z]

  # no point in time, as the date filters match it as well as `has_beginning`
  defp intent_beginning(user, has_beginning) do
    {:ok, intent} =
      Intents.create(user, intent(%{has_beginning: has_beginning, has_point_in_time: nil}))

    intent
  end

  test "an intent's has_beginning is stored in the time span mixin" do
    intent = intent_beginning(fake_agent!(), @begin_a)

    assert %TimeSpan{has_beginning: stored} = Repo.get(TimeSpan, intent.id)
    assert DateTime.compare(stored, @begin_a) == :eq
  end

  test "vf_intent no longer has its own has_beginning column" do
    assert %{rows: [[0]]} =
             Repo.query!(
               "select count(*) from information_schema.columns where table_name = 'vf_intent' and table_schema = current_schema() and column_name = 'has_beginning'"
             )
  end

  test "reading an intent returns its has_beginning" do
    intent = intent_beginning(fake_agent!(), @begin_a)

    assert %Intent{has_beginning: read} = Repo.get(Intent, intent.id)
    assert DateTime.compare(read, @begin_a) == :eq
  end

  test "a proposal's published intent is preloaded with its has_beginning" do
    user = fake_agent!()
    intent = intent_beginning(user, @begin_a)
    proposed_intent = fake_proposed_intent!(fake_proposal!(user), intent)

    assert %Intent{has_beginning: read} =
             Repo.preload(proposed_intent, :publishes, force: true).publishes

    assert DateTime.compare(read, @begin_a) == :eq
  end

  test "an intent with no has_beginning still has its mixin row, and is read" do
    intent = intent_beginning(fake_agent!(), nil)

    assert %TimeSpan{has_beginning: nil} = Repo.get(TimeSpan, intent.id)
    assert %Intent{has_beginning: nil} = Repo.get(Intent, intent.id)
  end

  # every intent has a time span row, so the view can inner-join it and an index on has_beginning can serve the default order
  test "the view inner-joins the time span, and has_beginning is indexed" do
    assert %{rows: [[definition]]} =
             Repo.query!("select pg_get_viewdef('vf_intent_view'::regclass)")

    assert definition =~ ~r/\bJOIN bonfire_data_time_span\b/
    refute definition =~ ~r/LEFT JOIN bonfire_data_time_span\b/

    assert %{rows: [[1]]} =
             Repo.query!(
               "select count(*) from pg_indexes where tablename = 'bonfire_data_time_span' and indexdef ~ '\\(has_beginning'"
             )
  end

  test "the date filters and the default order read has_beginning" do
    user = fake_agent!()
    ids = for begin <- [@begin_b, @begin_a, @begin_c], do: intent_beginning(user, begin).id

    assert {:ok, ordered} = Intents.many(id: ids, order: :default)

    assert Enum.map(ordered, &DateTime.to_date(&1.has_beginning)) == [
             ~D[2032-03-03],
             ~D[2031-02-02],
             ~D[2030-01-01]
           ]

    assert {:ok, from_b} = Intents.many(id: ids, start_date: @begin_b)

    assert from_b |> Enum.map(& &1.id) |> Enum.sort() ==
             Enum.sort(Enum.drop(ids, -2) ++ [List.last(ids)])
  end
end
