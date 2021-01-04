defmodule ValueFlows.ValueCalculation.Formula2Test do
  use Bonfire.ValueFlows.DataCase, async: true

  alias ValueFlows.ValueCalculation.Formula2

  # same as validate, just provides defaults
  def test_validate(formula, var_names) do
    Formula2.validate(formula, Formula2.default_env(), var_names, [max_runs: 200])
  end

  describe "parse" do
    test "different types of forms" do
      assert 1 == Formula2.parse("1")
      assert "a" == Formula2.parse("a")
      assert [1] == Formula2.parse("(1)")
      assert ["+", 1, 2] == Formula2.parse("(+ 1 2)")
      assert ["*", ["+", 1, 2], ["-", 1, "a"]] == Formula2.parse("(* (+ 1 2) (- 1 a))")
    end

    test "with new lines" do
      assert ["+", 1, 2] == Formula2.parse("\n( +  1 \n2)")
    end
  end

  describe "validate" do
    test "passes for a valid formula" do
      assert {:ok, _} = "(+ 1 2)" |> Formula2.parse() |> test_validate([])
      assert {:ok, _} = "(+ 1 a)" |> Formula2.parse() |> test_validate(["a"])
      assert {:ok, _} = "(* (+ 1 b) (- 1 a))" |> Formula2.parse() |> test_validate(["a", "b"])
    end

    test "fails if variable name does not exist" do
      assert {:error, %{original_failure: "Undefined variable: \"a\""}} =
        "(+ 1 a)" |> Formula2.parse() |> test_validate([])
    end
  end

  describe "evaluate" do
    test "self evaluating" do
      assert {:ok, 1} = "1" |> Formula2.parse() |> Formula2.eval(%{})
      assert {:ok, 3.14} = "3.14" |> Formula2.parse() |> Formula2.eval(%{})
    end

    test "default functions" do
      assert {:ok, 3} = "(+ 1 1 1)" |> Formula2.parse() |> Formula2.eval(Formula2.default_env())
      assert {:ok, 0} = "(- 3 2 1)" |> Formula2.parse() |> Formula2.eval(Formula2.default_env())
      assert {:ok, 6} = "(* 1 2 3)" |> Formula2.parse() |> Formula2.eval(Formula2.default_env())
      assert {:ok, 16.0} = "(pow 2 4)" |> Formula2.parse() |> Formula2.eval(Formula2.default_env())
    end

    test "fails if variable does not exist" do
      assert {:error, "Undefined variable: \"a\""} =
        "(+ 1 a)"
        |> Formula2.parse()
        |> Formula2.eval(Formula2.default_env())
    end
  end
end
