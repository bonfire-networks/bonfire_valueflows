# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.ValueCalculation.Formula2 do
  @type var_ref :: binary()
  @type value :: integer() | float()
  @type ast :: [var_ref() | value()]
  @type env :: %{var_ref() => ([value()] -> value())}

  @doc "Return the AST for a binary"
  @spec parse(binary()) :: ast()
  def parse(raw_string) when is_binary(raw_string) do
    raw_string
    |> tokenize()
    |> do_parse()
    |> List.first()
  end

  @doc """
  Validate that the AST only contains references to functions defined in
  the environment.

  May do replacement of function/variable names.
  """
  @spec validate(ast(), env()) :: {:ok, ast()} | {:error, term()}
  def validate(ast, %{} = env) when is_list(ast) do
    with :ok <- do_validate(ast, env), do: {:ok, ast}
  end

  @doc "Execute the AST over the environment."
  @spec execute(ast(), env()) :: {:ok, value()} | {:error, term()}
  def execute(ast, %{} = env) when is_list(ast) do
    # reduce the AST

    # fetch functions from env

    # pass parameters

    # accumulate

    # final result
  end

  defp tokenize(str) do
    # HACK
    str
    |> String.replace("(", " ( ")
    |> String.replace(")", " ) ")
    |> String.split()
  end

  defp do_parse(tokens, acc \\ [])

  defp do_parse(["(" | tail], acc) do
    {tokens, sub_tree} = do_parse(tail, [])
    do_parse(tokens, [sub_tree | acc])
  end

  defp do_parse([")" | tail], acc) do
    {tail, Enum.reverse(acc)}
  end

  defp do_parse([], acc) do
    Enum.reverse(acc)
  end

  # atom
  defp do_parse([head | tail], acc) do
    do_parse(tail, [atom(head) | acc])
  end

  # parse as an atom (a binary in erlang), float or integer
  defp atom(token) do
    case Integer.parse(token) do
      {value, ""} ->
        value

      :error ->
        case Float.parse(token) do
          {value, ""} -> value
          :error -> token
        end
    end
  end

  # TODO: make generic lisp walk ;)
  defp do_validate([sub_tree | tail], env) when is_list(sub_tree) do
    with :ok <- do_validate(sub_tree, env), do: do_validate(tail, env)
  end

  defp do_validate([head | tail], env) when is_binary(head) do
    if Map.has_key?(env, head) do
      do_validate(tail, env)
    else
      {:error, "Unknown variable name: #{head}"}
    end
  end

  defp do_validate([value | tail], env) do
    do_validate(tail, env)
  end

  defp do_validate([], env) do
    :ok
  end
end
