defmodule ValueFlows.EconomicEvent.EventSideEffects do
  # import Logger

  use Bonfire.Common.Utils
  import Bonfire.Common.Config, only: [repo: 0]

  alias ValueFlows.EconomicEvent
  # alias ValueFlows.EconomicEvent.EconomicEvents
  alias ValueFlows.EconomicResource.EconomicResources
  # alias ValueFlows.EconomicEvent.Queries

  @doc "Applies the event's effects on its resources. The resource updates among them are made as the person acting (`current_user:`, else the event's creator), so they are checked against the resource, not against the event."
  def event_side_effects(event, opts \\ [])

  def event_side_effects(
        %EconomicEvent{
          action: %{
            label: action,
            onhand_effect: onhand_effect,
            resource_effect: resource_effect
          },
          resource_quantity: quantity
        } = event,
        opts
      ) do
    event =
      repo().preload(event,
        resource_inventoried_as: [:accounting_quantity, :onhand_quantity],
        to_resource_inventoried_as: [:accounting_quantity, :onhand_quantity]
      )

    resource = event.resource_inventoried_as

    # TODO: the destination resource's quantity changes with no check on that resource, so anyone naming someone as receiver can add to their inventory unasked; decide whether it needs `:edit` on it, the receiver acting, or the receiver's acceptance
    to_resource = event.to_resource_inventoried_as

    # the person acting: never read as anyone else when missing, so the resource update is refused
    opts = [current_user: Keyword.get(opts, :current_user) || e(event, :creator, nil)]

    # REFERENCE ISSUE:  https://lab.allmende.io/valueflows/vf-app-specs/vf-apps/-/issues/4
    cond do
      # the event's own checks only ask that its creator is involved in it and accountable for the resource, so the quantity of the resource the event takes from or adds to is changed only by someone who may update that resource
      not is_nil(resource) and
        (resource_effect in ["increment", "decrement", "decrementIncrement"] or
           onhand_effect == "decrementIncrement") and
          ValueFlows.Util.can?(opts[:current_user], :edit, resource) != :ok ->
        {:error, :not_permitted}

      #     If action.resourceEffect is "+" or "-"
      resource_effect == "increment" or
          (resource_effect == "decrement" and
             event.resource_inventoried_as_id != nil) ->
        #         Add event resourceQuantity to accountingQuantity
        resource =
          quantity_effect(
            :accounting_quantity,
            resource,
            quantity,
            resource_effect,
            opts
          )

        #         Add event resourceQuantity to onhandQuantity
        resource = quantity_effect(:onhand_quantity, resource, quantity, resource_effect, opts)

        return_updated_event(event, resource)

      # ElseIf action.resourceEffect is "-+"
      resource_effect == "decrementIncrement" or
          onhand_effect == "decrementIncrement" ->
        # # (two resources can be affected)
        # If action is "transfer-custody" or "transfer-complete" or "move"
        cond do
          action == "transfer" or action == "move" ->
            #     If the from-resource exists
            #         Subtract event resourceQuantity from from_resource.onhandQuantity and accountingQuantity
            resource = quantity_effect(:onhand_quantity, resource, quantity, "decrement", opts)

            resource =
              quantity_effect(
                :accounting_quantity,
                resource,
                quantity,
                "decrement",
                opts
              )

            #     If the to-resource exists
            #         Add event resourceQuantity to to_resource.onhandQuantity and accountingQuantity
            to_resource =
              quantity_effect(
                :onhand_quantity,
                to_resource,
                quantity,
                "increment",
                opts
              )

            to_resource =
              quantity_effect(
                :accounting_quantity,
                to_resource,
                quantity,
                "increment",
                opts
              )

            return_updated_event(event, resource, to_resource)

          action == "transfer-custody" ->
            #     If the from-resource exists
            #         Subtract event resourceQuantity from from_resource.onhandQuantity
            resource = quantity_effect(:onhand_quantity, resource, quantity, "decrement", opts)

            #     If the to-resource exists
            #         Add event resourceQuantity to to_resource.onhandQuantity
            to_resource =
              quantity_effect(
                :onhand_quantity,
                to_resource,
                quantity,
                "increment",
                opts
              )

            return_updated_event(event, resource, to_resource)

          # ElseIf action is "transfer-all-rights" or "transfer-complete" or "move"
          action == "transfer-all-rights" ->
            #     If the from-resource exists
            #         Subtract event resourceQuantity from from_resource.accountingQuantity
            resource =
              quantity_effect(
                :accounting_quantity,
                resource,
                quantity,
                "decrement",
                opts
              )

            #     If the to-resource exists
            #         Add event resourceQuantity to to_resource.accountingQuantity
            to_resource =
              quantity_effect(
                :accounting_quantity,
                to_resource,
                quantity,
                "increment",
                opts
              )

            return_updated_event(event, resource, to_resource)

          # Else
          true ->
            {:ok, event}
        end

      # Else
      true ->
        {:ok, event}
    end
  end

  def quantity_effect(field, resource, quantity, operation, opts \\ [])

  def quantity_effect(
        :onhand_quantity,
        %{
          onhand_quantity: %{unit_id: onhand_unit} = _onhand_quantity
        } = _resource,
        %{unit_id: event_unit},
        _,
        _opts
      )
      when onhand_unit != event_unit do
    {:error,
     "The units used on the existing resource's onhand quantity (#{onhand_unit}) do not match the event's unit (#{event_unit})"}
  end

  def quantity_effect(
        :accounting_quantity,
        %{
          accounting_quantity: %{unit_id: accounting_unit} = _accounting_quantity
        } = _resource,
        %{unit_id: event_unit},
        _,
        _opts
      )
      when accounting_unit != event_unit do
    {:error,
     "The units used on the existing the resource's accounting quantity (#{accounting_unit}) do not match the event's unit (#{event_unit})"}
  end

  def quantity_effect(
        :onhand_quantity = _field,
        %{
          onhand_quantity: %{unit_id: onhand_unit} = onhand_quantity
        } = resource,
        %{unit_id: event_unit, has_numerical_value: amount} = _by_quantity,
        operation,
        _opts
      )
      when onhand_unit == event_unit do
    onhand_quantity = measurement_effect(operation, onhand_quantity, amount)

    %{resource | onhand_quantity: onhand_quantity}
  end

  def quantity_effect(
        :accounting_quantity = _field,
        %{
          accounting_quantity: %{unit_id: accounting_unit} = accounting_quantity
        } = resource,
        %{unit_id: event_unit, has_numerical_value: amount} = _by_quantity,
        operation,
        _opts
      )
      when accounting_unit == event_unit do
    accounting_quantity = measurement_effect(operation, accounting_quantity, amount)

    %{resource | accounting_quantity: accounting_quantity}
  end

  def quantity_effect(
        :onhand_quantity = _field,
        %{
          onhand_quantity_id: existing_quantity
        } = resource,
        by_quantity,
        _,
        opts
      )
      when is_nil(existing_quantity) do
    new_quantity = Bonfire.Quantify.Measure.copy(by_quantity)

    # Set onhandQuantity on a resource with no previous onhandQuantity, as the person acting: they must be allowed to update the resource itself
    with {:ok, resource} <-
           EconomicResources.update(resource, %{onhand_quantity: new_quantity},
             current_user: opts[:current_user]
           ) do
      resource
    end
  end

  def quantity_effect(
        :accounting_quantity = _field,
        %{
          accounting_quantity_id: existing_quantity
        } = resource,
        by_quantity,
        _,
        opts
      )
      when is_nil(existing_quantity) do
    new_quantity = Bonfire.Quantify.Measure.copy(by_quantity)

    # Set accountingQuantity on a resource with no previous accountingQuantity, as the person acting: they must be allowed to update the resource itself
    with {:ok, resource} <-
           EconomicResources.update(resource, %{accounting_quantity: new_quantity},
             current_user: opts[:current_user]
           ) do
      resource
    end
  end

  def quantity_effect(_, resource, _, _, _opts) do
    resource
  end

  def measurement_effect("decrement", measurement, amount) do
    # minus
    measurement_effect(nil, measurement, -amount)
  end

  def measurement_effect(_, %{id: id} = _measurement, amount) do
    Bonfire.Quantify.Measures.Queries.inc_quantity(id, amount)
    # reload the measurement
    {:ok, measurement} = Bonfire.Quantify.Measures.one(id: id)
    measurement
  end

  def return_updated_event(_event, {:error, e}) do
    {:error, e}
  end

  def return_updated_event(event, resource) do
    {:ok, %{event | resource_inventoried_as: resource}}
  end

  def return_updated_event(_event, {:error, e}, _) do
    {:error, e}
  end

  def return_updated_event(_event, _, {:error, e}) do
    {:error, e}
  end

  def return_updated_event(event, resource, to_resource) do
    {:ok,
     %{
       event
       | resource_inventoried_as: resource,
         to_resource_inventoried_as: to_resource
     }}
  end
end
