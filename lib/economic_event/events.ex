# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.EconomicEvent.EconomicEvents do
  use OK.Pipe

  import Bonfire.Common.Utils

  import Bonfire.Common.Config, only: [repo: 0]
  alias ValueFlows.Util

  # alias Bonfire.GraphQL
  alias Bonfire.GraphQL.{Fields, Page}

  alias ValueFlows.Knowledge.Resource
  alias ValueFlows.EconomicEvent
  alias ValueFlows.EconomicResource.EconomicResources
  alias ValueFlows.Knowledge.ResourceSpecification.ResourceSpecifications
  alias ValueFlows.EconomicEvent.Queries
  alias ValueFlows.EconomicEvent.EventSideEffects

  alias ValueFlows.Process.Processes
  alias ValueFlows.ValueCalculation.ValueCalculations

  import Bonfire.Fail.Error

  require Logger

  def federation_module, do: ["ValueFlows:EconomicEvent", "EconomicEvent"]

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  @doc """
  Retrieves a single one by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def one(filters), do: repo().single(Queries.query(EconomicEvent, filters))

  @doc """
  Retrieves a list of them by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def many(filters \\ []), do: {:ok, repo().many(Queries.query(EconomicEvent, filters))}

  def fields(group_fn, filters \\ [])
      when is_function(group_fn, 1) do
    {:ok, fields} = many(filters)
    {:ok, Fields.new(fields, group_fn)}
  end

  @doc """
  Retrieves an Page of events according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(EconomicEvent, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- repo().transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of events according to various filters

  Used by:
  * GraphQL resolver bulk resolution
  """
  def pages(
        cursor_fn,
        group_fn,
        page_opts,
        base_filters \\ [],
        data_filters \\ [],
        count_filters \\ []
      )

  def pages(cursor_fn, group_fn, page_opts, base_filters, data_filters, count_filters) do
    Bonfire.GraphQL.Pagination.pages(
      Queries,
      EconomicEvent,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end

  def preload_all(%EconomicEvent{} = event) do
    with {:ok, event} <- one(id: event.id, preload: :all) do
      preload_action(event)
    else _ ->
      preload_action(event)
    end
  end

  def preload_action(%{action_id: action_id} = event) when is_binary(action_id) do
    event |> Map.put(:action, ValueFlows.Knowledge.Action.Actions.action!(action_id))
  end
  def preload_action(%{action: action_id} = event) when is_binary(action_id) do
    event |> Map.put(:action, ValueFlows.Knowledge.Action.Actions.action!(action_id))
  end
  def preload_action(%{action: %{id: action_id}} = event) when is_binary(action_id) do
    event |> Map.put(:action, ValueFlows.Knowledge.Action.Actions.action!(action_id))
  end
  def preload_action(%{action: %{label: label}} = event) when is_binary(label) do
    event |> Map.put(:action, ValueFlows.Knowledge.Action.Actions.action!(label))
  end
  def preload_action(%{action: action} = event) do # fallback
    event |> Map.put(:action, action)
  end

  def inputs_of(attrs, action_id \\ nil)

  def inputs_of(process, action_id) when not is_nil(action_id) do
    case maybe_get_id(process) do
      id when is_binary(id) -> many([:default, input_of_id: id, action_id: action_id])
      _ -> {:ok, nil}
    end
  end

  def inputs_of(process, _) do
    case maybe_get_id(process) do
      id when is_binary(id) -> many([:default, input_of_id: id])
      _ -> {:ok, nil}
    end
  end

  def outputs_of(attrs, action_id \\ nil)

  def outputs_of(process, action_id) when not is_nil(action_id) do
    case maybe_get_id(process) do
      id when is_binary(id) -> many([:default, output_of_id: id, action_id: action_id])
      _ -> {:ok, nil}
    end
  end

  def outputs_of(process, _) do
    case maybe_get_id(process) do
      id when is_binary(id) -> many([:default, output_of_id: id])
      _ -> {:ok, nil}
    end
  end


  defdelegate trace(event, recurse_limit \\ Util.default_recurse_limit(), recurse_counter \\ 0), to: ValueFlows.EconomicEvent.Trace, as: :event
  defdelegate track(event, recurse_limit \\ Util.default_recurse_limit(), recurse_counter \\ 0), to: ValueFlows.EconomicEvent.Track, as: :event


  ## mutations

  @doc "Create an event, and possibly linked resources"
  def create(creator, event_attrs, extra_attrs \\ %{}) do
    create_somethings(creator, prepare_create_attrs(event_attrs, creator), extra_attrs)
  end


  defp create_somethings(creator, event_attrs, extra_attrs \\ %{})

  defp create_somethings(
        _creator,
        %{
          resource_inventoried_as: from_existing_resource,
          to_resource_inventoried_as: to_existing_resource
        },
        %{
          new_inventoried_resource: new_inventoried_resource
        }
      )
      when
        not is_nil(from_existing_resource) and not is_nil(to_existing_resource) and not is_nil(new_inventoried_resource) and new_inventoried_resource !=%{}
        and from_existing_resource !=to_existing_resource and from_existing_resource !=new_inventoried_resource and to_existing_resource !=new_inventoried_resource
      do

    error =  "Oops, you cannot act on three resources in one event."
    Logger.warn("Events.create/3: "<>error)

    IO.inspect(event_with_three_resources: [
      %{
        resource_inventoried_as: from_existing_resource,
        to_resource_inventoried_as: to_existing_resource
      },
      %{
        new_inventoried_resource: new_inventoried_resource
      }
    ])

    {:error, error}
  end

  defp create_somethings(
        creator,
        %{
          resource_inventoried_as: from_existing_resource,
          to_resource_inventoried_as: to_existing_resource
        } = event_attrs,
        _
      )
      when not is_nil(from_existing_resource) do
    Logger.notice("Events.create/3: recording an event between two EXISTING resources")

    create_event(creator, event_attrs)
  end

  defp create_somethings(
        creator,
        %{
          resource_inventoried_as: from_existing_resource
        } = event_attrs,
        %{
          new_inventoried_resource: new_inventoried_resource
        }
      )
      when not is_nil(from_existing_resource) do
    Logger.notice("Events.create/3: creating a new TO resource to go with an existing FROM resource")

    new_resource_attrs =
      new_inventoried_resource
      |> Map.put_new(:primary_accountable, Map.get(event_attrs, :receiver, creator))

    create_resource_and_event(
      creator,
      event_attrs,
      new_resource_attrs,
      :to_resource_inventoried_as_id
    )
  end

  defp create_somethings(
        creator,
        %{
          to_resource_inventoried_as: to_existing_resource
        } = event_attrs,
        %{
          new_inventoried_resource: new_inventoried_resource
        }
      )
      when not is_nil(to_existing_resource) do
    Logger.notice("Events.create/3: creating a new FROM resource to go with an existing TO resource")

    new_resource_attrs =
      new_inventoried_resource
      |> Map.put_new(:primary_accountable, Map.get(event_attrs, :provider, creator))

    create_resource_and_event(
      creator,
      event_attrs,
      new_resource_attrs,
      :resource_inventoried_as_id
    )
  end

  defp create_somethings(creator, event_attrs, %{
        new_inventoried_resource: new_inventoried_resource
      }) do

    Logger.notice("Events.create/3: creating a NEW resource")

    new_resource_attrs =
      new_inventoried_resource
      |> Map.put_new(:primary_accountable, Map.get(event_attrs, :provider, creator))

    create_resource_and_event(
      creator,
      event_attrs,
      new_resource_attrs,
      :resource_inventoried_as_id
    )
  end

  defp create_somethings(creator, %{action_id: action} = event_attrs, _) when is_binary(action) do
    create_with_action(creator, event_attrs, ValueFlows.Knowledge.Action.Actions.action!(action))
  end

  defp create_somethings(creator, event_attrs, _) do
    Logger.notice("Events.create/3: creating an event but NOT a resource")
    create_event(creator, event_attrs)
  end


  defp create_with_action(creator, event_attrs, %{resource_effect: resource_effect} = _action)
      when resource_effect == "increment" do

    Logger.notice("Events.create_with_action: incrementing (eg. producing or raising a new resource), using info from the event and/or resource_conforms_to")

    IO.inspect(create_with_action: event_attrs)

    resource_conforms_to = ResourceSpecifications.maybe_get(event_attrs)

    attrs = %{
          name: Map.get(event_attrs, :note, "Unknown Resource"),
          current_location: Map.get(event_attrs, :at_location),
          conforms_to: resource_conforms_to,
          # note: Map.get(event_attrs, :resource_note, "")
        }

    IO.inspect(attrs)
    create_somethings(creator, event_attrs, %{
        new_inventoried_resource: Bonfire.Common.Utils.maybe_to_map(
          attrs
            |> Map.merge(
              resource_conforms_to || %{}
            ))
            |> Map.merge(%{note: Map.get(event_attrs, :resource_note, "")})
      })
  end

  defp create_with_action(creator,
        %{
          resource_inventoried_as_id: resource_inventoried_as_id
        } = event_attrs,
        %{resource_effect: resource_effect} = _action)
      when resource_effect == "decrementIncrement" do

    log = "Events.create_with_action: decrementing+incrementing (eg. transfering or moving [part of] a resource)"
    # IO.inspect(create_with_action: event_attrs)

    attrs = %{
          name: Map.get(event_attrs, :note, "Unknown Resource"),
          current_location: Map.get(event_attrs, :at_location)
        }

    new_inventoried_resource_attrs = with {:ok, fetched} <- EconomicResources.one(id: resource_inventoried_as_id) do
      Logger.notice(log<>" creating the target resource based on info from resource_inventoried_as and the event")

      Bonfire.Common.Utils.maybe_to_map(
        attrs
        |> Map.merge(
          fetched || %{}
        ))

    else _ ->
      Logger.notice(log<>" creating a blank target resource (based on info from the event)")

      attrs
    end

    create_somethings(creator, event_attrs, %{
      new_inventoried_resource: new_inventoried_resource_attrs
    })

  end

  defp create_with_action(creator,
        %{
          resource_inventoried_as_id: resource_inventoried_as_id
        } = event_attrs,
        %{resource_effect: resource_effect} = _action)
      when resource_effect == "decrement" do

    log = "Events.create_with_action: decrementing (eg. consuming or lowering [part of] a resource)"
    # IO.inspect(create_with_action: event_attrs)

    attrs = %{
          name: Map.get(event_attrs, :note, "Unknown Resource"),
          current_location: Map.get(event_attrs, :at_location)
        }

    new_inventoried_resource_attrs = with {:ok, fetched} <- EconomicResources.one(id: resource_inventoried_as_id) do
      Logger.notice(log<>" creating the target resource based on info from resource_inventoried_as and the event")

      Bonfire.Common.Utils.maybe_to_map(
        attrs
        |> Map.merge(
          fetched || %{}
        ))

    else _ ->
      Logger.notice(log<>" creating a blank target resource (based on info from the event)")

      attrs
    end

    create_somethings(creator, event_attrs, %{
      new_inventoried_resource: new_inventoried_resource_attrs
    })

  end

  defp create_with_action(creator, event_attrs, _) do
    Logger.notice("Events.create_with_action: creating an event but not a resource")
    create_event(creator, event_attrs)
  end



  @doc "Create resource + event. Use create/3 instead."
  defp create_resource_and_event(creator, event_attrs, new_inventoried_resource, field_name \\ :resource_inventoried_as_id) do
    new_resource_attrs =
      new_inventoried_resource
      |> Map.put_new(:is_public, true)

    repo().transact_with(fn ->
      with {:ok, %{id: new_resource_id} = new_resource} <-
            EconomicResources.create(
              creator,
              new_resource_attrs
            ),
          {:ok, event_ret} <- create_event(
            creator,
            Map.merge(event_attrs, %{field_name => new_resource_id}
          )) do

        {:ok, event_ret |> Map.put(:economic_resource, new_resource)}
      end
    end)
  end

  @doc """
  Create an Event (with preexisting resources). Use create/3 instead.
  """
  defp create_event(%{} = creator, new_event_attrs) do

    repo().transact_with(fn ->
      with :ok <- validate_user_involvement(creator, new_event_attrs),
           :ok <- validate_provider_is_primary_accountable(new_event_attrs),
           :ok <- validate_receiver_is_primary_accountable(new_event_attrs),
           {:ok, event} <- repo().insert(EconomicEvent.create_changeset(creator, new_event_attrs)),
           {:ok, event} <- post_create_event(event, creator, new_event_attrs),
           {:ok, reciprocals} <- create_reciprocal_events(event) do
        {:ok, %{economic_event: event, reciprocal_events: reciprocals}}
      end
    end)
  end

  defp post_create_event(event, creator, attrs) do
    with event = preload_all(event),
         {:ok, event} <- maybe_transfer_resource(event),
         {:ok, event} <- EventSideEffects.event_side_effects(event),
         {:ok, event} <- ValueFlows.Util.try_tag_thing(creator, event, attrs),
         {:ok, activity} <- ValueFlows.Util.publish(creator, event.action_id, event) do
      indexing_object_format(event) |> ValueFlows.Util.index_for_search()
      {:ok, event}
    end
  end


  @doc """
  Find value calculations related to event and run them, generating reciprocal events.
  """
  defp create_reciprocal_events(%{} = event) do
    case ValueCalculations.one([:default, event: event]) do
      # FIXME: throw error on multiple calcs
      {:ok, calc} ->
        with {:ok, result} <- ValueCalculations.apply_to(event, calc) do
          new_event_attrs = event
          |> struct_to_map()
          |> Map.drop([:resource_inventoried_as_id, :to_resource_inventoried_as_id])
          |> Map.drop([:resource_quantity_id, :effort_quantity_id])
          |> Map.merge(%{
            action_id: calc.value_action_id,
            calculated_using_id: calc.id,
            triggered_by_id: event.id,
          })
          # don't overwrite if value not set
          |> maybe_put(
            :resource_conforms_to_id,
            calc.value_resource_conforms_to_id
          )
          |> Map.put(
            reciprocal_event_quantity_context(calc),
            %{
              unit_id: calc.value_unit_id,
              has_numerical_value: result,
            }
          )
          # |> IO.inspect(label: "create_reciprocal_events")

          EconomicEvent.create_changeset(event.creator, new_event_attrs)
          |> EconomicEvent.validate_create_changeset()
          |> repo().insert()
          ~>> post_create_event(event.creator, new_event_attrs)
        end

      {:error, :not_found} ->
        {:ok, []}
    end
  end

  # if valueAction is "work" or "use", calculate the effortQuantity, else calculate the resourceQuantity
  defp reciprocal_event_quantity_context(%{value_action_id: action_id} = _calc)
      when action_id in ["work", "use"], do: :effort_quantity
  defp reciprocal_event_quantity_context(_calc), do: :resource_quantity

  # TODO: take the user who is performing the update
  # @spec update(%EconomicEvent{}, attrs :: map) :: {:ok, EconomicEvent.t()} | {:error, Changeset.t()}
  def update(user, %EconomicEvent{} = event, attrs) do
    repo().transact_with(fn ->
      event = preload_all(event)
      attrs = prepare_attrs(attrs, e(event, :creator, nil))

      with :ok <- validate_user_involvement(user, event),
           {:ok, event} <- repo().update(EconomicEvent.update_changeset(event, attrs)),
           {:ok, event} <- maybe_transfer_resource(event),
           {:ok, event} <- ValueFlows.Util.try_tag_thing(nil, event, attrs),
           {:ok, _} <- ValueFlows.Util.publish(event, :update) do
        {:ok, event}
      end
    end)
  end

  defp maybe_transfer_resource(
         %EconomicEvent{
           to_resource_inventoried_as_id: to_resource_id,
           provider_id: provider_id,
           receiver_id: receiver_id,
           action_id: action_id
         } = event
       )
       when action_id in ["transfer", "transfer-all-rights"]
            and not is_nil(to_resource_id)
            and not is_nil(provider_id) and not is_nil(receiver_id)
            and provider_id != receiver_id do
    with {:ok, to_resource} <- EconomicResources.one([:default, id: to_resource_id]),
         :ok <- validate_provider_is_primary_accountable(event),
         {:ok, to_resource} <- EconomicResources.update(to_resource, %{primary_accountable: receiver_id}) do

            Logger.notice("Events.maybe_transfer_resource: updated the primary_accountable of the to_resource")
            {:ok, %{event | to_resource_inventoried_as: to_resource}}

         else _ ->
            Logger.notice("Events.maybe_transfer_resource: did not transfer the resource (could not find or update the to_resource, or user not authorized to do so)")
            {:ok, event}
    end
  end

  defp maybe_transfer_resource(event) do
    Logger.notice("Events.maybe_transfer_resource: did not transfer the resource (criteria not met)")
    {:ok, event}
  end

  defp validate_user_involvement(
         %{id: creator_id},
         %{provider_id: provider_id, receiver_id: receiver_id} = _event
       )
       when provider_id == creator_id or receiver_id == creator_id do
    # TODO add more complex rules once we have agent roles/relationships
    :ok
  end

  defp validate_user_involvement(
         %{id: creator_id},
         %{provider: provider, receiver: receiver} = _event
       )
       when (is_binary(provider) and is_binary(receiver) and provider == creator_id) or
              receiver == creator_id do
    :ok
  end

  defp validate_user_involvement(
         creator,
         %{provider: provider, receiver: receiver} = _event
       )
       when provider == creator or
              receiver == creator do
    :ok
  end

  defp validate_user_involvement(creator, event) do
    Logger.error("VF - Permission error, creator is #{inspect creator} and provider is #{inspect event.provider} and receiver is #{inspect event.receiver}")
   {:error, error(403, "You cannot do this if you are not receiver or provider.")}
  end

  defp validate_provider_is_primary_accountable(
         %{resource_inventoried_as_id: resource_id, provider_id: provider_id} = _event
       )
       when not is_nil(resource_id) and not is_nil(provider_id) do
    with {:ok, resource} <- EconomicResources.one([:default, id: resource_id]) do
      validate_provider_is_primary_accountable(%{
        resource_inventoried_as: resource,
        provider_id: provider_id
      })
    end
  end

  defp validate_provider_is_primary_accountable(
         %{resource_inventoried_as: resource, provider_id: provider_id} = _event
       )
       when is_struct(resource) and not is_nil(provider_id) do
    if is_nil(resource.primary_accountable_id) or provider_id == resource.primary_accountable_id do
      :ok
    else
      {:error, error(403, "You cannot do this since the provider is not accountable for the resource.")}
    end
  end

  defp validate_provider_is_primary_accountable(_event) do
    :ok
  end

  defp validate_receiver_is_primary_accountable(
         %{to_resource_inventoried_as_id: resource_id, receiver_id: receiver_id, provider_id: provider_id} = _event
       )
       when not is_nil(resource_id) do
    with {:ok, resource} <- EconomicResources.one([:default, id: resource_id]) do
      if is_nil(resource.primary_accountable_id)
         or receiver_id == resource.primary_accountable_id
         or provider_id == resource.primary_accountable_id do
        :ok
      else
        {:error, error(403, "You cannot do this since neither the receiver nor provider are accountable for the target resource.")}
      end
    end
  end

  defp validate_receiver_is_primary_accountable(_event) do
    :ok
  end

  def prepare_create_attrs(attrs, creator \\ nil) do
    attrs
    # fallbacks if none indicated
    |> Map.put_new(:provider, creator)
    |> Map.put_new(:receiver, creator)
    |> prepare_attrs(creator)
  end

  def prepare_attrs(attrs, creator \\ nil) do
    attrs
    |> maybe_put(:action_id, e(attrs, :action, :id, e(attrs, :action, nil) ) |> ValueFlows.Knowledge.Action.Actions.id)
    |> maybe_put(
      :context_id,
      attrs |> Map.get(:in_scope_of) |> maybe(&List.first/1)
    )
    |> maybe_put(:provider_id, attr_get_agent(attrs, :provider, creator))
    |> maybe_put(:receiver_id, attr_get_agent(attrs, :receiver, creator))
    |> maybe_put(:input_of_id, attr_get_id(attrs, :input_of))
    |> maybe_put(:output_of_id, attr_get_id(attrs, :output_of))
    |> maybe_put(:resource_conforms_to_id, attr_get_id(attrs, :resource_conforms_to))
    |> maybe_put(:resource_inventoried_as_id, attr_get_id(attrs, :resource_inventoried_as))
    |> maybe_put(:to_resource_inventoried_as_id, attr_get_id(attrs, :to_resource_inventoried_as))
    |> maybe_put(:triggered_by_id, attr_get_id(attrs, :triggered_by))
    |> maybe_put(:at_location_id, attr_get_id(attrs, :at_location))
    |> maybe_put(:calculated_using_id, attr_get_id(attrs, :calculated_using))
    |> Util.parse_measurement_attrs(creator)
    |> IO.inspect(label: "Events: prepared attrs")
  end

  def attr_get_agent(attrs, field, creator) do
    case Map.get(attrs, field) do
      "me" -> maybe_get_id(creator)
      other -> maybe_get_id(other)
    end
  end

  def soft_delete(%EconomicEvent{} = event) do
    repo().transact_with(fn ->
      with {:ok, event} <- Bonfire.Repo.Delete.soft_delete(event),
           {:ok, _} <- ValueFlows.Util.publish(event, :deleted) do
        {:ok, event}
      end
    end)
  end

  def indexing_object_format(obj) do
    %{
      "index_type" => "ValueFlows.EconomicEvent",
      "id" => obj.id,
      # "url" => obj.character.canonical_url,
      # "icon" => icon,
      "summary" => Map.get(obj, :note),
      "published_at" => obj.published_at,
      "creator" => ValueFlows.Util.indexing_format_creator(obj)
      # "index_instance" => URI.parse(obj.character.canonical_url).host, # home instance of object
    }
  end

  def ap_publish_activity(activity_name, thing) do
    ValueFlows.Util.Federation.ap_publish_activity(activity_name, :economic_event, thing, 2, [
    ])
  end

  def ap_receive_activity(creator, activity, object) do
    with {:ok, %{economic_event: event}} <- ValueFlows.Util.Federation.ap_receive_activity(creator, activity, object, &create/2) do
      {:ok, event}
    end
  end


end
