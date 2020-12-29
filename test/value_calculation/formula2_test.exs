defmodule ValueFlows.ValueCalculation.Formula2Test do
  use Bonfire.ValueFlows.DataCase, async: true

  alias ValueFlows.ValueCalculation.Formula2

  describe "parse" do
    test "different types of forms" do
      assert [1] == Formula2.parse("1")
      assert ["a"] == Formula2.parse("a")
      assert [1] == Formula2.parse("(1)")
      assert ["+", 1, 2] == Formula2.parse("(+ 1 2)")
      assert ["*", ["+", 1, 2], ["-", 1, "a"]] == Formula2.parse("(* (+ 1 2) (- 1 a))")
    end
  end

  describe "validate" do
  end

  describe "evaluate" do
  end
end
