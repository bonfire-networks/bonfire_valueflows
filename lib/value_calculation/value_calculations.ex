# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.ValueCalculation.ValueCalculations do
  use Arrows
  use Bonfire.Common.Utils, only: [maybe: 2]

  import Bonfire.Common.Config, only: [repo: 0]

  alias ValueFlows.ValueCalculation
  alias ValueFlows.ValueCalculation.Queries

  alias ValueFlows.EconomicEvent
  alias ValueFlows.Observe.Observations

  def one(filters), do: repo().single(Queries.query(ValueCalculation, filters))

  def many(filters \\ []),
    do: {:ok, repo().many(Queries.query(ValueCalculation, filters))}

  def preload_all(%ValueCalculation{} = calculation) do
    # should always succeed
    {:ok, calculation} = one(id: calculation.id, preload: :all)
    calculation
  end

  @doc "Apply the value calculation to a context"
  def apply_to(%EconomicEvent{} = event, %ValueCalculation{formula: formula} = _calc) do
    # TODO: consider other libs like https://github.com/narrowtux/abacus
    # see https://elixirforum.com/t/expression-evaluate-user-input-expressions/61126
    Formula2.parse_and_eval(formula, formula_env(event))
    ~> Formula2.decimal_to_float()
  end

  def create(%{} = user, attrs) do
    attrs = prepare_attrs(attrs)

    with :ok <- prepare_formula(attrs),
         {:ok, calculation} <-
           repo().insert(ValueCalculation.create_changeset(user, attrs)) do
      {:ok, preload_all(calculation)}
    end
  end

  def update(%ValueCalculation{} = calculation, attrs) do
    attrs = prepare_attrs(attrs)

    with :ok <- prepare_formula(attrs),
         {:ok, calculation} <-
           repo().update(ValueCalculation.update_changeset(calculation, attrs)) do
      {:ok, preload_all(calculation)}
    end
  end

  def soft_delete(%ValueCalculation{} = calculation) do
    Bonfire.Common.Repo.Delete.soft_delete(calculation)
  end

  defp formula_context(:event),
    do: ["resourceQuantity", "effortQuantity", "quality"]

  defp formula_env(%EconomicEvent{} = event) do
    resource_id =
      Map.get(
        event,
        :resource_inventoried_as_id,
        Map.get(event, :to_resource_inventoried_as_id)
      )

    observation =
      if resource_id do
        case Observations.one([
               :default,
               preload: :all,
               has_feature_of_interest: resource_id,
               order: :id,
               limit: 1
             ]) do
          {:ok, x} -> repo().preload(x, [:result_phenomenon])
          _ -> nil
        end
      end

    ValueFlows.Util.map_values(
      %{
        "resourceQuantity" => event.resource_quantity.has_numerical_value,
        "effortQuantity" => event.effort_quantity.has_numerical_value,
        "quality" =>
          if is_nil(observation) do
            0
          else
            observation.result_phenomenon.extra_info["formula_quantifier"]
          end
      },
      &Formula2.float_to_decimal/1
    )
  end

  defp prepare_formula(%{formula: formula}) do
    Formula2.parse_and_validate(formula, formula_context(:event), formula2_options())
  end

  defp prepare_formula(_attrs), do: :ok

  defp prepare_attrs(attrs) do
    attrs
    |> Enums.maybe_put(
      :context_id,
      attrs |> Map.get(:in_scope_of) |> maybe(&List.first/1)
    )
    |> Enums.maybe_put(:value_unit_id, Enums.attr_get_id(attrs, :value_unit))
    |> Enums.maybe_put(
      :action_id,
      Enums.attr_get_id(attrs, :action) |> ValueFlows.Knowledge.Action.Actions.id()
    )
    |> Enums.maybe_put(:value_action_id, attrs[:value_action])
    |> Enums.maybe_put(
      :resource_conforms_to_id,
      Enums.attr_get_id(attrs, :resource_conforms_to)
    )
    |> Enums.maybe_put(
      :value_resource_conforms_to_id,
      Enums.attr_get_id(attrs, :value_resource_conforms_to)
    )
  end

  if Application.compile_env!(:bonfire, :env) == :test do
    defp formula2_options, do: [max_runs: 100]
  else
    defp formula2_options, do: [max_runs: 1_000]
  end
end
