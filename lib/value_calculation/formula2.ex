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
      "*" => fn [a, b] -> a * b end,
      # TODO: division is disabled until an if condition is added that works on numbers only (false on 0 only)
      # TODO: so you can do (if var-a (/ 1 var-a) 1), avoiding division by 0 if var-a = 0
      # "/" => fn [a, b] -> a / b end,
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
  def validate(ast, %{} = env, var_names, options \\ []) when is_list(var_names) do
    value_gen = StreamData.one_of([StreamData.integer(), StreamData.float()])
    env_gen = StreamData.fixed_map(for v <- var_names, do: {v, value_gen})

    options = Keyword.merge([initial_seed: :os.timestamp(), max_runs: 5_000], options)
    StreamData.check_all( env_gen, options,
      fn new_env ->
        try do
          eval(ast, Map.merge(env, new_env))
        rescue e ->
          {:error, %{reason: e, env: new_env}}
        end
      end
    )
  end

  @doc "Execute the AST over the environment."
  @spec eval(ast(), env()) :: {:ok, value()} | {:error, term()}
  def eval(ast, %{} = env) do
    case ast do
      [operator | args] when is_list(args) ->
        with {:ok, operator_fn} <- eval(operator, env),
             {:ok, parameters} <- eval_parameters(args, env) do
          {:ok, do_apply(operator_fn, parameters)}
        end

      value when is_integer(value) or is_float(value) ->
        {:ok, value}

      variable when is_binary(variable) ->
        lookup_variable_value(variable, env)

      _ ->
        {:error, "Unknown operation: #{inspect(ast)}"}
    end
  end

  defp do_apply(operator, args) when is_function(operator, 1) do
    operator.(args)
  end

  defp eval_parameters(args, env) do
    # TODO: find the helper I wrote for this
     Enum.reduce_while(args, [], fn arg, acc ->
      case eval(arg, env) do
        {:ok, val} -> {:cont, [val | acc]}
        {:error, reason} -> {:halt, {:error, reason}}
      end
     end)
     |> case do
      {:error, _} = e -> e
      val -> {:ok, Enum.reverse(val)}
     end
  end

  defp lookup_variable_value(var_name, env) do
    with :error <- Map.fetch(env, var_name) do
      {:error, "Undefined variable: #{inspect(var_name)}"}
    end
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
    case parse_integer(token) do
      :error ->
        case Float.parse(token) do
          {value, ""} -> value
          :error -> token
        end

      value -> value
    end
  end

  defp parse_integer(token) do
    case Integer.parse(token) do
      {value, ""} ->
        value

      {_, decimal} when is_binary(decimal) ->
        :error

      :error -> :error
    end
  end
end
