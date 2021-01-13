# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.ValueCalculation.ValueCalculations do
  import Bonfire.Common.Utils, only: [maybe_put: 3, maybe: 2, attr_get_id: 2]

  import Bonfire.Common.Config, only: [repo: 0]

  alias ValueFlows.ValueCalculation
  alias ValueFlows.ValueCalculation.{Formula2, Queries}

  alias ValueFlows.Observation.EconomicEvent

  def one(filters), do: repo().single(Queries.query(ValueCalculation, filters))

  def many(filters \\ []), do: {:ok, repo().all(Queries.query(ValueCalculation, filters))}

  def preload_all(%ValueCalculation{} = calculation) do
    # should always succeed
    {:ok, calculation} = one(id: calculation.id, preload: :all)
    calculation
  end

  @doc "Apply the value calculation to a context"
  def apply_to(%EconomicEvent{} = event) do
    with {:ok, calc} <- one(event.calculated_using_id),
         {:ok, result} <- evaluate_formula(event, calc) do
      {:ok, %{value_calculation: calc, result: result}}
    end
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

  defp formula_context(:event),
    do: ["resourceQuantity", "availableQuantity", "effortQuantity"]

  defp evaluate_formula(context, %{formula: formula} = calculation) do
    # TODO: populate env with context vars
    env = Map.merge(Formula2.default_env(), %{})

    formula
    |> Formula2.parse()
    |> Formula2.eval()
  end

  defp prepare_formula(%{formula: formula}) do
    available_vars = formula_context(:event)

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
    |> maybe_put(
      :context_id,
      attrs |> Map.get(:in_scope_of) |> maybe(&List.first/1)
    )
    |> maybe_put(:value_unit_id, attr_get_id(attrs, :value_unit))
    |> maybe_put(:action_id, attr_get_id(attrs, :action))
  end

  if Bonfire.Common.Config.get(:env) == :test do
  defp formula2_options, do: [max_runs: 100]
  else
  defp formula2_options, do: [max_runs: 1_000]
  end
end
