defmodule ValueFlows.Process.ProcessesTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  import Bonfire.Common.Simulation




  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.Process.Processes

  describe "one" do
    test "fetches an existing process by ID" do
      user = fake_agent!()
      spec = fake_process!(user)

      assert {:ok, fetched} = Processes.one(id: spec.id)
      assert_process(fetched)
      assert {:ok, fetched} = Processes.one(user: user)
      assert_process(fetched)
    end

    test "cannot fetch a deleted process" do
      user = fake_agent!()
      spec = fake_process!(user)
      assert {:ok, spec} = Processes.soft_delete(spec)
      assert {:error, :not_found} =
              Processes.one([:deleted, id: spec.id])
    end
  end

  describe "create" do
    test "can create a process" do
      user = fake_agent!()

      assert {:ok, process} = Processes.create(user, process())
      assert_process(process)
    end

    test "can create a process with context" do
      user = fake_agent!()
      parent = fake_agent!()

      attrs = %{in_scope_of: [parent.id]}
      assert {:ok, process} = Processes.create(user, process(attrs))
      assert_process(process)
      assert process.context.id == parent.id
    end

    test "can create a process with tags" do
      user = fake_agent!()
      tags = some_fake_categories(user)

      attrs = process(%{tags: tags})
      assert {:ok, process} = Processes.create(user, attrs)
      assert_process(process)

      process = repo().preload(process, :tags)
      assert Enum.count(process.tags) == Enum.count(tags)
    end
  end

  describe "update" do
    test "can update an existing process" do
      user = fake_agent!()
      spec = fake_process!(user)

      assert {:ok, updated} = Processes.update(spec, process())
      assert_process(updated)
      assert updated.updated_at != spec.updated_at
    end
  end

  describe "soft delete" do
    test "delete an existing process" do
      user = fake_agent!()
      spec = fake_process!(user)

      refute spec.deleted_at
      assert {:ok, spec} = Processes.soft_delete(spec)
      assert spec.deleted_at
    end

  end

end
