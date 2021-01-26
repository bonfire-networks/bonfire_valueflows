# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.ValueCalculation.ValueCalculations do
  use OK.Pipe

  import Bonfire.Common.Utils, only: [maybe_put: 3, maybe: 2, attr_get_id: 2]

  import Bonfire.Common.Config, only: [repo: 0]

  alias ValueFlows.ValueCalculation
  alias ValueFlows.ValueCalculation.{Formula2, Queries}

  alias ValueFlows.EconomicEvent
  alias ValueFlows.Observe.Observations

  def one(filters), do: repo().single(Queries.query(ValueCalculation, filters))

  def many(filters \\ []), do: {:ok, repo().all(Queries.query(ValueCalculation, filters))}

  def preload_all(%ValueCalculation{} = calculation) do
    # should always succeed
    {:ok, calculation} = one(id: calculation.id, preload: :all)
    calculation
  end

  @doc "Apply the value calculation to a context"
  def apply_to(%EconomicEvent{} = event, %ValueCalculation{} = calc) do
    env = Map.merge(Formula2.default_env(), formula_env(event))
    calc.formula
    |> Formula2.parse()
    |> Formula2.eval(env)
    ~> Formula2.decimal_to_float()
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
    do: ["resourceQuantity", "effortQuantity", "quality"]

  defp formula_env(%EconomicEvent{} = event) do
    observation = case Observations.one([
      :default,
      # TODO: figure out what resource to use
      has_feature_of_interest: event.resource_inventoried_as_id,
      order: :id,
      limit: 1
    ]) do
      {:ok, x} -> x
      {:error, :not_found} -> nil
    end

    %{
      "resourceQuantity" => event.resource_quantity.has_numerical_value,
      "effortQuantity" => event.effort_quantity.has_numerical_value,
      "quality" => maybe(observation, &(&1.result_phenomenon.formula_quantifier or 0.0)),
    }
    |> ValueFlows.Util.map_values(&Formula2.float_to_decimal/1)
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
    |> maybe_put(:action_id, attrs[:action])
    |> maybe_put(:value_action_id, attrs[:value_action])
    |> maybe_put(:resource_conforms_to_id, attr_get_id(attrs, :resource_conforms_to))
    |> maybe_put(:value_resource_conforms_to_id, attr_get_id(attrs, :value_resource_conforms_to))
  end

  if Bonfire.Common.Config.get(:env) == :test do
  defp formula2_options, do: [max_runs: 100]
  else
  defp formula2_options, do: [max_runs: 1_000]
  end
end
