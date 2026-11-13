defmodule Bonfire.ValueFlows.NeedleMixinViewTest do
  use Bonfire.ValueFlows.DataCase, async: false

  @moduletag :backend

  import ValueFlows.Simulate

  alias Bonfire.Common.Repo
  alias ValueFlows.Planning.Intent

  @table "vf_intent"
  @view "vf_intent_view_test"
  @mixin "bonfire_data_time_span"
  @begin_a "2030-01-01 10:00:00+00"
  @begin_b "2031-02-02 12:30:00+00"

  setup context do
    # an intent made by the schema needs the table's own has_beginning column, so it is made before that column goes
    intent = if context[:with_intent], do: fake_intent!(fake_agent!())

    # the view selects t.*, so the table's has_beginning would duplicate the mixin's column; the sandbox rolls the drop back
    # Repo.query!(~s[alter table "#{@table}" drop column has_beginning])
    # `if exists`: once the data move has run, the table no longer has the column
    Repo.query!(~s[alter table "#{@table}" drop column if exists has_beginning])

    base_columns =
      Repo.query!(
        "select column_name from information_schema.columns where table_name = $1 and table_schema = current_schema() and column_name <> 'has_beginning' order by ordinal_position",
        [@table]
      ).rows
      |> List.flatten()

    mixins = [{@mixin, ["has_beginning"]}]

    # the public helper returns the function and the trigger as one string, and one query runs one statement
    [function_sql, trigger_sql] =
      @table
      |> Needle.Migration.mixin_view_trigger_sql(@view, base_columns, mixins)
      |> String.split(";\ncreate trigger ", parts: 2)

    Repo.query!(Needle.Migration.mixin_view_sql(@table, @view, mixins))
    Repo.query!(function_sql)
    Repo.query!(~s[drop trigger if exists "#{@view}_mixin_view_trigger" on "#{@view}"])
    Repo.query!("create trigger " <> trigger_sql)

    {:ok, base_columns: base_columns, intent: intent}
  end

  defp new_id do
    {:ok, bin} = Needle.UID.dump(Needle.UID.generate())
    Ecto.UUID.cast!(bin)
  end

  defp insert_row(id, begin \\ @begin_a) do
    begin_sql = if begin, do: "'#{begin}'::timestamptz", else: "null"

    Repo.query!("""
    insert into #{@view} (id, name, action_id, updated_at, has_beginning)
    values ('#{id}'::uuid, 'test intent', 'work', now(), #{begin_sql})
    """)
  end

  defp rows(sql), do: Repo.query!(sql).rows

  defp mixin_rows(id), do: rows("select has_beginning from #{@mixin} where id = '#{id}'::uuid")
  defp base_rows(id), do: rows("select name, action_id from #{@table} where id = '#{id}'::uuid")

  defp pointer_rows(id),
    do: rows("select table_id, deleted_at from pointers_pointer where id = '#{id}'::uuid")

  defp intent_table_uuid do
    {:ok, bin} = Needle.UID.dump(Intent.__pointers__(:table_id))
    Ecto.UUID.cast!(bin)
  end

  defp uuid_of(bin), do: Ecto.UUID.cast!(bin)

  test "(a) insert through the view writes base row, mixin row and pointer" do
    id = new_id()
    insert_row(id)

    assert [["test intent", "work"]] = base_rows(id)
    assert [[~U[2030-01-01 10:00:00.000000Z]]] = mixin_rows(id)

    assert [[table_id, nil]] = pointer_rows(id)
    assert uuid_of(table_id) == intent_table_uuid()
  end

  test "(a) insert returning id gives the row back" do
    id = new_id()

    assert %{rows: [[returned]]} =
             Repo.query!("""
             insert into #{@view} (id, name, action_id, updated_at, has_beginning)
             values ('#{id}'::uuid, 'test intent', 'work', now(), '#{@begin_a}'::timestamptz)
             returning id
             """)

    assert uuid_of(returned) == id
  end

  test "(b) update of has_beginning changes the mixin row and leaves the base row" do
    id = new_id()
    insert_row(id)

    Repo.query!(
      "update #{@view} set has_beginning = '#{@begin_b}'::timestamptz where id = '#{id}'::uuid"
    )

    assert [[~U[2031-02-02 12:30:00.000000Z]]] = mixin_rows(id)
    assert [["test intent", "work"]] = base_rows(id)
  end

  test "(c) delete through the view removes base row and mixin row, and marks the pointer deleted" do
    id = new_id()
    insert_row(id)

    Repo.query!("delete from #{@view} where id = '#{id}'::uuid")

    assert [] = base_rows(id)
    assert [] = mixin_rows(id)
    assert [[_table_id, %DateTime{}]] = pointer_rows(id)
  end

  test "(d) insert on conflict through the view is refused by Postgres" do
    id = new_id()

    assert_raise Postgrex.Error, fn ->
      Repo.query!("""
      insert into #{@view} (id, name, action_id, updated_at, has_beginning)
      values ('#{id}'::uuid, 'test intent', 'work', now(), '#{@begin_a}'::timestamptz)
      on conflict (id) do nothing
      """)
    end
  end

  test "(e) setting has_beginning to null keeps a mixin row with null" do
    id = new_id()
    insert_row(id)

    Repo.query!("update #{@view} set has_beginning = null where id = '#{id}'::uuid")

    assert [[nil]] = mixin_rows(id)
  end

  @tag :with_intent
  test "(f) update through the view of an intent with no mixin row creates one", %{intent: intent} do
    {:ok, bin} = Needle.UID.dump(intent.id)
    id = Ecto.UUID.cast!(bin)

    # an intent made through the view now gets a mixin row; one from before the data move with no `has_beginning` has none, as the move copies only values
    Repo.query!("delete from #{@mixin} where id = '#{id}'::uuid")
    assert [] = mixin_rows(id)

    Repo.query!(
      "update #{@view} set has_beginning = '#{@begin_b}'::timestamptz where id = '#{id}'::uuid"
    )

    assert [[~U[2031-02-02 12:30:00.000000Z]]] = mixin_rows(id)
  end
end
