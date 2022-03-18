defmodule ValueFlows.Knowledge.ProcessSpecification.ProcessSpecificationsTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  # import Bonfire.Common.Simulation

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.Knowledge.ProcessSpecification.ProcessSpecifications

  describe "one" do
    test "fetches an existing process specification by ID" do
      user = fake_agent!()
      spec = fake_process_specification!(user)

      assert {:ok, fetched} = ProcessSpecifications.one(id: spec.id)
      assert_process_specification(fetched)
      assert {:ok, fetched} = ProcessSpecifications.one(user: user)
      assert_process_specification(fetched)
    end

    test "cannot fetch a deleted process specification" do
      user = fake_agent!()
      spec = fake_process_specification!(user)
      assert {:ok, spec} = ProcessSpecifications.soft_delete(spec)
      assert {:error, :not_found} = ProcessSpecifications.one([:deleted, id: spec.id])
    end
  end

  describe "create" do
    test "can create a process specification" do
      user = fake_agent!()

      assert {:ok, spec} = ProcessSpecifications.create(user, process_specification())
      assert_process_specification(spec)
    end

    test "can create a process specification with context" do
      user = fake_agent!()

      attrs = %{in_scope_of: [fake_agent!().id]}

      assert {:ok, spec} = ProcessSpecifications.create(user, process_specification(attrs))
      assert_process_specification(spec)
      assert spec.context_id == hd(attrs.in_scope_of)
    end

    test "can create a process_specification with tags" do
      user = fake_agent!()
tags = some_fake_categories(user)

      attrs = process_specification(%{tags: tags})
      assert {:ok, process_specification} = ProcessSpecifications.create(user, attrs)
      assert_process_specification(process_specification)

      process_specification = repo().preload(process_specification, :tags)
      assert Enum.count(process_specification.tags) == Enum.count(tags)
    end
  end

  describe "update" do
    test "can update an existing process specification" do
      user = fake_agent!()
      spec = fake_process_specification!(user)

      assert {:ok, updated} = ProcessSpecifications.update(spec, process_specification())
      assert_process_specification(updated)
      assert updated.updated_at != spec.updated_at
    end
  end

  describe "soft delete" do
    test "delete an existing process specification" do
      user = fake_agent!()
      spec = fake_process_specification!(user)

      refute spec.deleted_at
      assert {:ok, spec} = ProcessSpecifications.soft_delete(spec)
      assert spec.deleted_at
    end
  end
end
