# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.ValueCalculation.ValueCalculations do
  import Bonfire.Common.Utils, only: [maybe_put: 3, maybe: 2]

  import Bonfire.Common.Config, only: [repo: 0]
  @user Bonfire.Common.Config.get!(:user_schema)

  alias ValueFlows.ValueCalculation
  alias ValueFlows.ValueCalculation.{Formula2, Queries}

  def one(filters), do: repo().single(Queries.query(ValueCalculation, filters))

  def many(filters \\ []), do: {:ok, repo().all(Queries.query(ValueCalculation, filters))}

  def preload_all(%ValueCalculation{} = calculation) do
    # should always succeed
    {:ok, calculation} = one(id: calculation.id, preload: :all)
    calculation
  end

  def create(%{} = user, attrs) do
    attrs = prepare_attrs(attrs)

    with :ok <- prepare_formula(attrs),
         {:ok, calculation} <- repo().insert(ValueCalculation.create_changeset(user, attrs)) do
      {:ok, preload_all(calculation)}
    end
  end

  def update(%ValueCalculation{} = calculation, attrs) do
    attrs = prepare_attrs(attrs)

    with :ok <- prepare_formula(attrs),
          {:ok, calculation} <- repo().update(ValueCalculation.update_changeset(calculation, attrs)) do
      {:ok, preload_all(calculation)}
    end
  end

  def soft_delete(%ValueCalculation{} = calculation) do
    Bonfire.Repo.Delete.soft_delete(calculation)
  end

  defp prepare_formula(%{formula: formula}) do
    available_vars = ["resourceQuantity", "availableQuantity", "effortQuantity"]

    formula
    |> Formula2.parse()
    |> Formula2.validate(Formula2.default_env(), available_vars, formula2_options())
    |> case do
      {:ok, _} -> :ok
      e -> e
    end
  end

  defp prepare_formula(_attrs), do: :ok

  defp prepare_attrs(attrs) do
    attrs
    |> maybe_put(:context_id,
      attrs |> Map.get(:in_scope_of) |> maybe(&List.first/1)
    )
    |> maybe_put(:value_unit_id, Map.get(attrs, :value_unit))
  end

  if Mix.env() == :test do
  defp formula2_options, do: [max_runs: 100]
  else
  defp formula2_options, do: [max_runs: 1_000]
  end

end
