defmodule ValueFlows.Knowledge.ResourceSpecification.ResourceSpecificationsTest do
  use Bonfire.ValueFlows.ConnCase, async: true

  # import Bonfire.Common.Simulation




  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.Knowledge.ResourceSpecification.ResourceSpecifications

  describe "one" do
    test "fetches an existing resource specification by ID" do
      user = fake_agent!()
      spec = fake_resource_specification!(user)

      assert {:ok, fetched} = ResourceSpecifications.one(id: spec.id)
      assert_resource_specification(fetched)
      assert {:ok, fetched} = ResourceSpecifications.one(user: user)
      assert_resource_specification(fetched)
    end

    test "cannot fetch a deleted resource specification" do
      user = fake_agent!()
      spec = fake_resource_specification!(user)
      assert {:ok, spec} = ResourceSpecifications.soft_delete(spec)
      assert {:error, :not_found} =
              ResourceSpecifications.one([:deleted, id: spec.id])
    end
  end

  describe "create" do
    test "can create a resource specification" do
      user = fake_agent!()

      assert {:ok, spec} = ResourceSpecifications.create(user, resource_specification())
      assert_resource_specification(spec)
    end

    test "can create a resource specification with context" do
      user = fake_agent!()
      parent = fake_agent!()

      attrs = %{in_scope_of: [parent.id]}

      assert {:ok, spec} = ResourceSpecifications.create(user, resource_specification(attrs))
      assert_resource_specification(spec)
      assert spec.context_id == parent.id
    end

    test "can create a resource_specification with tags" do
      user = fake_agent!()
      tags = some_fake_categories(user)

      attrs = resource_specification(%{tags: tags})
      assert {:ok, resource_specification} = ResourceSpecifications.create(user, attrs)
      assert_resource_specification(resource_specification)

      resource_specification = repo().preload(resource_specification, :tags)
      assert Enum.count(resource_specification.tags) == Enum.count(tags)
    end
  end

  describe "update" do
    test "can update an existing resource specification" do
      user = fake_agent!()
      spec = fake_resource_specification!(user)

      assert {:ok, updated} = ResourceSpecifications.update(spec, resource_specification())
      assert_resource_specification(updated)
      assert updated.updated_at != spec.updated_at
    end
  end

  describe "soft delete" do
    test "delete an existing resource specification" do
      user = fake_agent!()
      spec = fake_resource_specification!(user)

      refute spec.deleted_at
      assert {:ok, spec} = ResourceSpecifications.soft_delete(spec)
      assert spec.deleted_at
    end

  end

end
