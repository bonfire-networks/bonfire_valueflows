# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.ValueCalculation.Formula2 do
  @type ast :: map()
  @type value :: integer() | float()
  @type env :: %{atom() => ([value()] -> value())}

  @doc "Return the AST for a binary"
  @spec parse(binary()) :: {:ok, ast()} | {:error, term()}
  def parse(raw_string) when is_binary(raw_string) do

  end

  @doc """
  Validate that the AST only contains references to functions defined in
  the environment.

  May do replacement of function/variable names.
  """
  @spec validate(ast(), env()) :: {:ok, ast()} | {:error, term()}
  def validate(%{} = ast, %{} = env) do

  end

  @doc "Execute the AST over the environment, returning the final results."
  @spec execute(ast(), env()) :: {:ok, value()} | {:error, term()}
  def execute(%{} = ast, %{} = env) do

  end
end
