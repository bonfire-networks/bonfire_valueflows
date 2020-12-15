# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.ValueCalculation.Formula2 do
  @type var_ref :: binary()
  @type value :: integer() | float()
  @type ast :: [var_ref() | value()]
  @type env :: %{var_ref() => ([value()] -> value())}

  def default_env do
    %{
      # TODO: make variadic
      "+" => fn [a, b] -> a + b end,
      "-" => fn [a, b] -> a - b end,
      "/" => fn [a, b] -> a / b end,
      "*" => fn [a, b] -> a * b end,
    }
  end

  @doc "Return the AST for a binary"
  @spec parse(binary()) :: ast()
  def parse(raw_string) when is_binary(raw_string) do
    raw_string
    |> tokenize()
    |> do_parse()
    |> List.first()
  end

  @doc """
  Run property tests against the given
  """
  @spec validate(ast(), env(), [var_ref()]) :: :ok | {:error, term()}
  def validate(ast, %{} = env, var_names) when is_list(var_names) do
    value_gen = StreamData.one_of([StreamData.integer(), StreamData.float()])

    env_gen = StreamData.fixed_map(for v <- var_names, do: {v, value_gen})

    for new_env <- Enum.take(env_gen, 100) do
       eval(ast, Map.merge(env, new_env))
    end
  end

  @doc "Execute the AST over the environment."
  @spec eval(ast(), env()) :: {:ok, value()} | {:error, term()}
  def eval(ast, %{} = env) do
    case ast do
      [operator | args] when is_list(args) ->
        do_apply(eval(operator, env), eval_parameters(args, env))

      value when is_integer(value) or is_float(value) ->
        value

      variable when is_binary(variable) ->
        lookup_variable_value(variable, env)

      _ -> # TODO: throw error
    end
  end

  defp do_apply(operator, args) when is_function(operator, 1) do
    # :erlang.apply(operator, args)
    operator.(args)
  end

  defp eval_parameters(args, env), do: Enum.map(args, &eval(&1, env))

  defp lookup_variable_value(var_name, env) do
    Map.fetch!(env, var_name)
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
end
