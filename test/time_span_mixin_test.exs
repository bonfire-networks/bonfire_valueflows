defmodule ValueFlows.TimeSpanMixinTest do
  # each VF type with a time span keeps `has_beginning` and `has_end` in the `Bonfire.Data.Time.TimeSpan` mixin, read and written through a view over its table that inner-joins the mixin
  use Bonfire.ValueFlows.DataCase, async: true

  import ValueFlows.Simulate

  alias Bonfire.Common.Repo
  alias Bonfire.Data.Time.TimeSpan

  @begin ~U[2030-01-01 10:00:00.000000Z]
  @end_ ~U[2030-01-02 18:00:00.000000Z]

  # {type, table, schema}
  @types [
    {:intent, "vf_intent", ValueFlows.Planning.Intent},
    {:commitment, "vf_commitment", ValueFlows.Planning.Commitment},
    {:economic_event, "vf_event", ValueFlows.EconomicEvent},
    {:proposal, "vf_proposal", ValueFlows.Proposal},
    {:process, "vf_process", ValueFlows.Process}
  ]

  # no point in time, as some types refuse one together with a beginning or end
  defp create(:intent, user, dates),
    do: fake_intent!(user, Map.put(dates, :has_point_in_time, nil))

  defp create(:commitment, user, dates) do
    {:ok, commitment} =
      ValueFlows.Planning.Commitment.Commitments.create(
        user,
        Map.merge(%{action: "produce", has_point_in_time: nil}, dates)
      )

    commitment
  end

  defp create(:economic_event, user, dates),
    do: fake_economic_event!(user, Map.put(dates, :has_point_in_time, nil))

  defp create(:proposal, user, dates), do: fake_proposal!(user, dates)
  defp create(:process, user, dates), do: fake_process!(user, dates)

  for {type, table, schema} <- @types do
    describe "#{type}" do
      test "stores both dates in the time span mixin" do
        thing = create(unquote(type), fake_agent!(), %{has_beginning: @begin, has_end: @end_})

        assert %TimeSpan{has_beginning: b, has_end: e} = Repo.get(TimeSpan, thing.id)
        assert DateTime.compare(b, @begin) == :eq
        assert DateTime.compare(e, @end_) == :eq
      end

      test "reads both dates back through its view" do
        thing = create(unquote(type), fake_agent!(), %{has_beginning: @begin, has_end: @end_})

        assert %{has_beginning: b, has_end: e} = Repo.get(unquote(schema), thing.id)
        assert DateTime.compare(b, @begin) == :eq
        assert DateTime.compare(e, @end_) == :eq
      end

      test "still has a mixin row, and is read, with no dates" do
        thing = create(unquote(type), fake_agent!(), %{has_beginning: nil, has_end: nil})

        assert %TimeSpan{has_beginning: nil, has_end: nil} = Repo.get(TimeSpan, thing.id)
        assert %{has_beginning: nil} = Repo.get(unquote(schema), thing.id)
      end

      test "its table no longer has the date columns, and its view inner-joins the mixin" do
        assert %{rows: [[0]]} =
                 Repo.query!(
                   "select count(*) from information_schema.columns where table_name = $1 and table_schema = current_schema() and column_name in ('has_beginning', 'has_end')",
                   [unquote(table)]
                 )

        assert %{rows: [[definition]]} =
                 Repo.query!("select pg_get_viewdef(($1::text)::regclass)", [
                   unquote(table) <> "_view"
                 ])

        assert definition =~ ~r/\bJOIN bonfire_data_time_span\b/
        refute definition =~ ~r/LEFT JOIN bonfire_data_time_span\b/
      end
    end
  end
end
