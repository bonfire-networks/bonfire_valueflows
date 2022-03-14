# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Test.Faking do
  # import ExUnit.Assertions

  import Bonfire.API.GraphQL.Test.GraphQLAssertions
  import Bonfire.API.GraphQL.Test.GraphQLFields

  #

  import ValueFlows.Simulate
  #
  import Grumble

  alias ValueFlows.Planning.Intent
  # alias ValueFlows.Planning.Intent.Intents
  alias ValueFlows.Knowledge.Action
  alias ValueFlows.Knowledge.ProcessSpecification
  alias ValueFlows.Knowledge.ResourceSpecification

  alias ValueFlows.{
    EconomicEvent,
    EconomicResource,
    Process
  }

  alias ValueFlows.{
    Claim,
    Proposal,
    ValueCalculation,
    # Proposals
  }

  alias ValueFlows.Proposal.{ProposedTo, ProposedIntent}

  # def assert_agent(%{} = a) do
  #   assert_agent(Map.from_struct(a))
  # end

  def assert_agent(a) do
    assert_object(a, :assert_agent,
      name: &assert_binary/1,
      note: assert_optional(&assert_binary/1),
      display_username: assert_optional(&assert_binary/1),
      canonical_url: assert_optional(&assert_binary/1)
    )
  end


  def assert_action(%Action{} = action) do
    assert_action(Map.from_struct(action))
  end

  def assert_action(action) do
    assert_object(action, :assert_action,
      label: &assert_binary/1,
      input_output: assert_optional(&assert_binary/1),
      pairs_with: assert_optional(&assert_binary/1),
      resource_effect: &assert_binary/1,
      onhand_effect: assert_optional(&assert_binary/1),
      note: assert_optional(&assert_binary/1)
    )
  end

  def assert_claim(%Claim{} = claim) do
    assert_claim(Map.from_struct(claim))
  end

  def assert_claim(claim) do
    assert_object(claim, :assert_claim,
      note: assert_optional(&assert_binary/1),
      agreed_in: assert_optional(&assert_binary/1),
      finished: assert_optional(&assert_boolean/1),
      created: assert_optional(&assert_datetime/1),
      due: assert_optional(&assert_datetime/1),
      resource_classified_as: assert_optional(assert_list(&assert_url/1))
    )
  end

  def assert_value_calculation(%ValueCalculation{} = calculation) do
    assert_value_calculation(Map.from_struct(calculation))
  end

  def assert_value_calculation(calculation) do
    assert_object(calculation, :assert_value_calculation,
      formula: &assert_binary/1,
      resource_classified_as: assert_optional(assert_list(&assert_url/1))
    )
  end

  def assert_resource_specification(%ResourceSpecification{} = spec) do
    assert_resource_specification(Map.from_struct(spec))
  end

  def assert_resource_specification(spec) do
    assert_object(spec, :assert_resource_specification,
      name: &assert_binary/1,
      note: assert_optional(&assert_binary/1)
      # classified_as: assert_optional(assert_list(&assert_url/1))
    )
  end

  def assert_process_specification(%ProcessSpecification{} = spec) do
    assert_process_specification(Map.from_struct(spec))
  end

  def assert_process_specification(spec) do
    assert_object(spec, :assert_process_specification,
      name: &assert_binary/1,
      note: assert_optional(&assert_binary/1)
      # classified_as: assert_optional(assert_list(&assert_url/1))
    )
  end

  def assert_process(%Process{} = spec) do
    assert_process(Map.from_struct(spec))
  end

  def assert_process(spec) do
    assert_object(spec, :assert_process,
      name: &assert_binary/1,
      note: assert_optional(&assert_binary/1)
      # classified_as: assert_optional(assert_list(&assert_url/1))
    )
  end

  def assert_proposal(%Proposal{} = proposal) do
    assert_proposal(Map.from_struct(proposal))
  end

  def assert_proposal(proposal) do
    assert_object(proposal, :assert_proposal,
      id: &assert_ulid/1,
      name: &assert_binary/1,
      note: &assert_binary/1,
      unit_based: &assert_boolean/1,
      has_beginning: assert_optional(&assert_datetime/1),
      has_end: assert_optional(&assert_datetime/1),
      created: assert_optional(&assert_datetime/1)
    )
  end

  def assert_proposal(%Proposal{} = proposal, %{} = proposal2) do
    assert_proposals_eq(proposal, assert_proposal(proposal2))
  end

  def assert_proposal_full(%Proposal{} = proposal) do
    assert_proposal_full(Map.from_struct(proposal))
  end

  def assert_proposal_full(proposal) do
    assert_object(proposal, :assert_proposal,
      id: &assert_ulid/1,
      name: &assert_binary/1,
      note: &assert_binary/1,
      unit_based: &assert_boolean/1,
      has_beginning: &assert_datetime/1,
      has_end: &assert_datetime/1,
      created: &assert_datetime/1
    )
  end

  def assert_proposal_full(%Proposal{} = proposal, %{} = proposal2) do
    assert_proposals_eq(proposal, assert_proposal_full(proposal2))
  end

  def assert_proposals_eq(%Proposal{} = proposal, %{} = proposal2) do
    assert_maps_eq(proposal, proposal2, :assert_proposal, [
      :name,
      :note,
      :unit_based,
      :has_beginning,
      :has_end,
      :created
    ])
  end

  def assert_proposed_intent(%ProposedIntent{} = pi) do
    assert_proposed_intent(Map.from_struct(pi))
  end

  def assert_proposed_intent(pi) do
    assert_object(pi, :assert_proposed_intent,
      id: &assert_ulid/1,
      reciprocal: assert_optional(&assert_boolean/1)
    )
  end

  def assert_proposed_to(%ProposedTo{} = pt) do
    assert_proposed_to(Map.from_struct(pt))
  end

  def assert_proposed_to(pt) do
    assert_object(pt, :assert_proposed_to, id: &assert_ulid/1)
  end

  def assert_intent(%Intent{} = intent) do
    assert_intent(Map.from_struct(intent))
  end

  def assert_intent(intent) do
    assert_object(intent, :assert_intent,
      id: &assert_ulid/1,
      name: &assert_binary/1,
      note: &assert_binary/1,
      finished: &assert_boolean/1,
      # TODO
      # resource_quantity: assert_optional(&Bonfire.Quantify.Test.Faking.assert_measure/1),
      # effort_quantity: assert_optional(&Bonfire.Quantify.Test.Faking.assert_measure/1),
      # available_quantity: assert_optional(&Bonfire.Quantify.Test.Faking.assert_measure/1),
      has_beginning: assert_optional(&assert_datetime/1),
      has_end: assert_optional(&assert_datetime/1),
      has_point_in_time: assert_optional(&assert_datetime/1),
      due: assert_optional(&assert_datetime/1),
      resource_classified_as: assert_optional(assert_list(&assert_url/1))
    )
  end

  def assert_intent(%Intent{} = intent, %{} = intent2) do
    assert_intents_eq(intent, assert_intent(intent2))
  end

  def assert_intents_eq(%Intent{} = intent, %{} = intent2) do
    assert_maps_eq(intent, intent2, :assert_intent, [
      :name,
      :note,
      :finished,
      :has_beginning,
      :has_end,
      :has_point_in_time,
      :due
    ])
  end

  def assert_economic_event(%EconomicEvent{} = event) do
    assert_economic_event(Map.from_struct(event))
  end

  def assert_economic_event(event) do
    assert_object(event, :assert_economic_event,
      note: assert_optional(&assert_binary/1)
      # classified_as: assert_optional(assert_list(&assert_url/1))
    )
  end

  def assert_economic_resource(%EconomicResource{} = resource) do
    assert_economic_resource(Map.from_struct(resource))
  end

  def assert_economic_resource(resource) do
    assert_object(resource, :assert_economic_resource,
      note: assert_optional(&assert_binary/1),
      name: assert_optional(&assert_binary/1),
      tracking_identifier: assert_optional(&assert_binary/1)
      # state_id: assert_optional(&assert_binary/1),
      # state: assert_optional(&assert_action/1),
    )
  end

  ## Graphql

  def claim_fields(extra \\ []) do
    extra ++ ~w(id note agreed_in finished created due resource_classified_as)a
  end

  def claim_response_fields(extra \\ []) do
    [claim: claim_fields(extra)]
  end

  def claim_query(options \\ []) do
    options = Keyword.put_new(options, :id_type, :id)
    gen_query(:id, &claim_subquery/1, options)
  end

  def claim_subquery(options \\ []) do
    gen_subquery(:id, :claim, &claim_fields/1, options)
  end

  def claims_query(options \\ []) do
    gen_query(&claims_subquery/1, options)
  end

  def claims_subquery(options \\ []) do
    fields = Keyword.get(options, :fields, [])
    fields = fields ++ claim_fields(fields)
    field(:claims, [{:fields, fields} | options])
  end

  def create_claim_mutation(options \\ []) do
    [claim: type!(:claim_create_params)]
    |> gen_mutation(&create_claim_submutation/1, options)
  end

  def create_claim_submutation(options \\ []) do
    [claim: var(:claim)]
    |> gen_submutation(:create_claim, &claim_response_fields/1, options)
  end

  def update_claim_mutation(options \\ []) do
    [claim: type!(:claim_update_params)]
    |> gen_mutation(&update_claim_submutation/1, options)
  end

  def update_claim_submutation(options \\ []) do
    [claim: var(:claim)]
    |> gen_submutation(:update_claim, &claim_response_fields/1, options)
  end

  def delete_claim_mutation(options \\ []) do
    [id: type!(:id)]
    |> gen_mutation(&delete_claim_submutation/1, options)
  end

  def delete_claim_submutation(_options \\ []) do
    field(:delete_claim, args: [id: var(:id)])
  end

  def value_calculation_fields(extra \\ []) do
    extra ++ ~w(id formula resource_classified_as)a
  end

  def value_calculation_response_fields(extra \\ []) do
    [value_calculation: value_calculation_fields(extra)]
  end

  def value_calculation_query(options \\ []) do
    options = Keyword.put_new(options, :id_type, :id)
    gen_query(:id, &value_calculation_subquery/1, options)
  end

  def value_calculation_subquery(options \\ []) do
    gen_subquery(:id, :value_calculation, &value_calculation_fields/1, options)
  end

  def value_calculations_pages_query(options \\ []) do
    params =
      [
        value_calculations_after: list_type(:cursor),
        value_calculations_before: list_type(:cursor),
        value_calculations_limit: :int
      ] ++ Keyword.get(options, :params, [])

    gen_query(&value_calculations_pages_subquery/1, [{:params, params} | options])
  end

  def value_calculations_pages_subquery(options \\ []) do
    args = [
      after: var(:value_calculations_after),
      before: var(:value_calculations_before),
      limit: var(:value_calculations_limit)
    ]

    page_subquery(
      :value_calculations_pages,
      &value_calculation_fields/1,
      [{:args, args} | options]
    )
  end


  def create_value_calculation_mutation(options \\ []) do
    [value_calculation: type!(:value_calculation_create_params)]
    |> gen_mutation(&create_value_calculation_submutation/1, options)
  end

  def create_value_calculation_submutation(options \\ []) do
    [value_calculation: var(:value_calculation)]
    |> gen_submutation(:create_value_calculation, &value_calculation_response_fields/1, options)
  end

  def update_value_calculation_mutation(options \\ []) do
    [value_calculation: type!(:value_calculation_update_params)]
    |> gen_mutation(&update_value_calculation_submutation/1, options)
  end

  def update_value_calculation_submutation(options \\ []) do
    [value_calculation: var(:value_calculation)]
    |> gen_submutation(:update_value_calculation, &value_calculation_response_fields/1, options)
  end

  def delete_value_calculation_mutation(options \\ []) do
    [id: type!(:id)]
    |> gen_mutation(&delete_value_calculation_submutation/1, options)
  end

  def delete_value_calculation_submutation(_options \\ []) do
    field(:delete_value_calculation, args: [id: var(:id)])
  end

  def person_fields(extra \\ []) do
    extra ++
      ~w(name note agent_type canonical_url image display_username)a
  end

  def person_subquery(options \\ []) do
    gen_subquery(:id, :person, &person_fields/1, options)
  end

  def person_query(options \\ []) do
    options = Keyword.put_new(options, :id_type, :id)
    gen_query(:id, &person_subquery/1, options)
  end

  def people_subquery(options \\ []) do
    fields = Keyword.get(options, :fields, [])
    fields = fields ++ person_fields(fields)
    field(:people, [{:fields, fields} | options])
  end

  def people_query(options \\ []) do
    gen_query(&people_subquery/1, options)
  end

  def action_fields(extra \\ []) do
    extra ++
      ~w(label input_output pairs_with resource_effect onhand_effect note)a
  end

  def action_subquery(options \\ []) do
    gen_subquery(:id, :action, &action_fields/1, options)
  end

  def actions_subquery(options \\ []) do
    fields = Keyword.get(options, :fields, [])
    fields = fields ++ action_fields(fields)
    field(:actions, [{:fields, fields} | options])
  end

  def action_query(options \\ []) do
    options = Keyword.put_new(options, :id_type, :id)
    gen_query(:id, &action_subquery/1, options)
  end

  def actions_query(options \\ []) do
    gen_query(&actions_subquery/1, options)
  end

  def intent_fields(extra \\ []) do
    extra ++
      ~w(id name note has_beginning has_end has_point_in_time due finished)a ++
      ~w(resource_classified_as)a
  end

  def intent_response_fields(extra \\ []) do
    [intent: intent_fields(extra)]
  end

  def intent_subquery(options \\ []) do
    gen_subquery(:id, :intent, &intent_fields/1, options)
  end

  def intent_query(options \\ []) do
    options = Keyword.put_new(options, :id_type, :id)
    gen_query(:id, &intent_subquery/1, options)
  end

  def intents_subquery(options \\ []) do
    fields = Keyword.get(options, :fields, [])
    fields = fields ++ intent_fields(fields)
    field(:intents, [{:fields, fields} | options])
  end

  def intents_query(options \\ []) do
    gen_query(&intents_subquery/1, options)
  end

  def intents_pages_subquery(options \\ []) do
    args = [
      after: var(:intents_after),
      before: var(:intents_before),
      limit: var(:intents_limit)
    ]

    page_subquery(
      :intents_pages,
      &intent_fields/1,
      [{:args, args} | options]
    )
  end

  def intents_pages_query(options \\ []) do
    params =
      [
        intents_after: list_type(:cursor),
        intents_before: list_type(:cursor),
        intents_limit: :int
      ] ++ Keyword.get(options, :params, [])

    gen_query(&intents_pages_subquery/1, [{:params, params} | options])
  end

  def create_offer_mutation(options \\ []) do
    [intent: type!(:intent_create_params)]
    |> gen_mutation(&create_offer_submutation/1, options)
  end

  def create_offer_submutation(options \\ []) do
    [intent: var(:intent)]
    |> gen_submutation(:create_offer, &intent_response_fields/1, options)
  end

  def create_need_mutation(options \\ []) do
    [intent: type!(:intent_create_params)]
    |> gen_mutation(&create_need_submutation/1, options)
  end

  def create_need_submutation(options \\ []) do
    [intent: var(:intent)]
    |> gen_submutation(:create_need, &intent_response_fields/1, options)
  end

  def create_intent_mutation(options \\ []) do
    [intent: type!(:intent_create_params)]
    |> gen_mutation(&create_intent_submutation/1, options)
  end

  def create_intent_submutation(options \\ []) do
    [intent: var(:intent)]
    |> gen_submutation(:create_intent, &intent_response_fields/1, options)
  end

  def update_intent_mutation(options \\ []) do
    [intent: type!(:intent_update_params)]
    |> gen_mutation(&update_intent_submutation/1, options)
  end

  def update_intent_submutation(options \\ []) do
    [intent: var(:intent)]
    |> gen_submutation(:update_intent, &intent_response_fields/1, options)
  end

  def delete_intent_mutation(options \\ []) do
    [id: type!(:id)]
    |> gen_mutation(&delete_intent_submutation/1, options)
  end

  def delete_intent_submutation(_options \\ []) do
    field(:delete_intent, args: [id: var(:id)])
  end

  def proposal_response_fields(extra \\ []) do
    [proposal: proposal_fields(extra)]
  end

  def proposal_query(options \\ []) do
    options = Keyword.put_new(options, :id_type, :id)
    gen_query(:id, &proposal_subquery/1, options)
  end

  def proposal_subquery(options \\ []) do
    gen_subquery(:id, :proposal, &proposal_fields/1, options)
  end

  def proposals_pages_subquery(options \\ []) do
    args = [
      after: var(:after),
      before: var(:before),
      limit: var(:limit)
    ]

    page_subquery(
      :proposals_pages,
      &proposal_fields/1,
      [{:args, args} | options]
    )
  end

  def proposals_pages_query(options \\ []) do
    params =
      [
        after: list_type(:cursor),
        before: list_type(:cursor),
        limit: :int
      ] ++ Keyword.get(options, :params, [])

    gen_query(&proposals_pages_subquery/1, [{:params, params} | options])
  end


  def create_proposal_mutation(options \\ []) do
    [proposal: type!(:proposal_create_params)]
    |> gen_mutation(&create_proposal_submutation/1, options)
  end

  def create_proposal_submutation(options \\ []) do
    [proposal: var(:proposal)]
    |> gen_submutation(:create_proposal, &proposal_response_fields/1, options)
  end

  def update_proposal_mutation(options \\ []) do
    [proposal: type!(:proposal_update_params)]
    |> gen_mutation(&update_proposal_submutation/1, options)
  end

  def update_proposal_submutation(options \\ []) do
    [proposal: var(:proposal)]
    |> gen_submutation(:update_proposal, &proposal_response_fields/1, options)
  end

  def delete_proposal_mutation(options \\ []) do
    [id: type!(:id)]
    |> gen_mutation(&delete_proposal_submutation/1, options)
  end

  def delete_proposal_submutation(_options \\ []) do
    field(:delete_proposal, args: [id: var(:id)])
  end

  def proposed_intent_fields(extra \\ []) do
    extra ++ ~w(id reciprocal)a
  end

  def proposed_intent_response_fields(extra \\ []) do
    [proposed_intent: proposed_intent_fields(extra)]
  end

  def propose_intent_mutation(options \\ []) do
    [
      published_in: type!(:id),
      publishes: type!(:id),
      reciprocal: type(:boolean)
    ]
    |> gen_mutation(&propose_intent_submutation/1, options)
  end

  def propose_intent_submutation(options \\ []) do
    [
      published_in: var(:published_in),
      publishes: var(:publishes),
      reciprocal: var(:reciprocal)
    ]
    |> gen_submutation(:propose_intent, &proposed_intent_response_fields/1, options)
  end

  def delete_proposed_intent_mutation(options \\ []) do
    [id: type!(:id)]
    |> gen_mutation(&delete_proposed_intent_submutation/1, options)
  end

  def delete_proposed_intent_submutation(_options \\ []) do
    field(:delete_proposed_intent, args: [id: var(:id)])
  end

  def proposed_to_fields(extra \\ []) do
    extra ++ ~w(id)a
  end

  def proposed_to_response_fields(extra \\ []) do
    [proposed_to: proposed_to_fields(extra)]
  end

  def propose_to_mutation(options \\ []) do
    [
      proposed: type!(:id),
      proposed_to: type!(:id)
    ]
    |> gen_mutation(&propose_to_submutation/1, options)
  end

  def propose_to_submutation(options \\ []) do
    [
      proposed: var(:proposed),
      proposed_to: var(:proposed_to)
    ]
    |> gen_submutation(:propose_to, &proposed_to_response_fields/1, options)
  end

  def delete_proposed_to_mutation(options \\ []) do
    [id: type!(:id)]
    |> gen_mutation(&delete_proposed_to_submutation/1, options)
  end

  def delete_proposed_to_submutation(_options \\ []) do
    field(:delete_proposed_to, args: [id: var(:id)])
  end

  def resource_specification_fields(extra \\ []) do
    extra ++ ~w(id name note)a
  end

  def resource_specification_response_fields(extra \\ []) do
    [resource_specification: resource_specification_fields(extra)]
  end

  def resource_specification_query(options \\ []) do
    options = Keyword.put_new(options, :id_type, :id)
    gen_query(:id, &resource_specification_subquery/1, options)
  end

  def resource_specification_subquery(options \\ []) do
    gen_subquery(:id, :resource_specification, &resource_specification_fields/1, options)
  end

  def create_resource_specification_mutation(options \\ []) do
    [resource_specification: type!(:resource_specification_create_params)]
    |> gen_mutation(&create_resource_specification_submutation/1, options)
  end

  def create_resource_specification_submutation(options \\ []) do
    [resource_specification: var(:resource_specification)]
    |> gen_submutation(
      :create_resource_specification,
      &resource_specification_response_fields/1,
      options
    )
  end

  def update_resource_specification_mutation(options \\ []) do
    [resource_specification: type!(:resource_specification_update_params)]
    |> gen_mutation(&update_resource_specification_submutation/1, options)
  end

  def update_resource_specification_submutation(options \\ []) do
    [resource_specification: var(:resource_specification)]
    |> gen_submutation(
      :update_resource_specification,
      &resource_specification_response_fields/1,
      options
    )
  end

  def delete_resource_specification_mutation(options \\ []) do
    [id: type!(:id)]
    |> gen_mutation(&delete_resource_specification_submutation/1, options)
  end

  def delete_resource_specification_submutation(_options \\ []) do
    field(:delete_resource_specification, args: [id: var(:id)])
  end

  def process_specification_fields(extra \\ []) do
    extra ++ ~w(id name note)a
  end

  def process_specification_response_fields(extra \\ []) do
    [process_specification: process_specification_fields(extra)]
  end

  def process_specification_query(options \\ []) do
    options = Keyword.put_new(options, :id_type, :id)
    gen_query(:id, &process_specification_subquery/1, options)
  end

  def process_specification_subquery(options \\ []) do
    gen_subquery(:id, :process_specification, &process_specification_fields/1, options)
  end

  def create_process_specification_mutation(options \\ []) do
    [process_specification: type!(:process_specification_create_params)]
    |> gen_mutation(&create_process_specification_submutation/1, options)
  end

  def create_process_specification_submutation(options \\ []) do
    [process_specification: var(:process_specification)]
    |> gen_submutation(
      :create_process_specification,
      &process_specification_response_fields/1,
      options
    )
  end

  def update_process_specification_mutation(options \\ []) do
    [process_specification: type!(:process_specification_update_params)]
    |> gen_mutation(&update_process_specification_submutation/1, options)
  end

  def update_process_specification_submutation(options \\ []) do
    [process_specification: var(:process_specification)]
    |> gen_submutation(
      :update_process_specification,
      &process_specification_response_fields/1,
      options
    )
  end

  def delete_process_specification_mutation(options \\ []) do
    [id: type!(:id)]
    |> gen_mutation(&delete_process_specification_submutation/1, options)
  end

  def delete_process_specification_submutation(_options \\ []) do
    field(:delete_process_specification, args: [id: var(:id)])
  end

  def process_fields(extra \\ []) do
    extra ++ ~w(id name note)a
  end

  def process_response_fields(extra \\ []) do
    [process: process_fields(extra)]
  end

  def process_query(options \\ []) do
    options = Keyword.put_new(options, :id_type, :id)
    gen_query(:id, &process_subquery/1, options)
  end

  def process_subquery(options \\ []) do
    gen_subquery(:id, :process, &process_fields/1, options)
  end

  def process_inputs_query(options \\ []) do
    query(
      name: "test",
      params: [id: type!(:id), action_id: type(:id)],
      fields: [
        field(
          :process,
          args: [id: var(:id)],
          fields:
            process_fields() ++
              [
                field(
                  :inputs,
                  [{:args, [action: var(:action_id)]} | options]
                )
              ]
        )
      ]
    )
  end

  def process_outputs_query(options \\ []) do
    query(
      name: "test",
      params: [id: type!(:id), action_id: type(:id)],
      fields: [
        field(
          :process,
          args: [id: var(:id)],
          fields:
            process_fields() ++
              [
                field(
                  :outputs,
                  [{:args, [action: var(:action_id)]} | options]
                )
              ]
        )
      ]
    )
  end

  def processes_subquery(options \\ []) do
    fields = Keyword.get(options, :fields, [])
    fields = fields ++ process_fields(fields)
    field(:processes, [{:fields, fields} | options])
  end

  def processes_query(options \\ []) do
    gen_query(&processes_subquery/1, options)
  end

  def processes_pages_subquery(options \\ []) do
    args = [
      after: var(:processes_after),
      before: var(:processes_before),
      limit: var(:processes_limit)
    ]

    page_subquery(
      :processes_pages,
      &process_fields/1,
      [{:args, args} | options]
    )
  end

  def processes_pages_query(options \\ []) do
    params =
      [
        processes_after: list_type(:cursor),
        processes_before: list_type(:cursor),
        processes_limit: :int
      ] ++ Keyword.get(options, :params, [])

    gen_query(&processes_pages_subquery/1, [{:params, params} | options])
  end

  def create_process_mutation(options \\ []) do
    [process: type!(:process_create_params)]
    |> gen_mutation(&create_process_submutation/1, options)
  end

  def create_process_submutation(options \\ []) do
    [process: var(:process)]
    |> gen_submutation(:create_process, &process_response_fields/1, options)
  end

  def update_process_mutation(options \\ []) do
    [process: type!(:process_update_params)]
    |> gen_mutation(&update_process_submutation/1, options)
  end

  def update_process_submutation(options \\ []) do
    [process: var(:process)]
    |> gen_submutation(:update_process, &process_response_fields/1, options)
  end

  def delete_process_mutation(options \\ []) do
    [id: type!(:id)]
    |> gen_mutation(&delete_process_submutation/1, options)
  end

  def delete_process_submutation(_options \\ []) do
    field(:delete_process, args: [id: var(:id)])
  end

  def economic_event_fields(extra \\ []) do
    extra ++ ~w(id note)a
  end

  def economic_event_response_fields(extra \\ []) do
    [economic_event: economic_event_fields(extra)]
  end

  def economic_event_response_fields(extra_event, extra_resource) do
    [
      economic_event: economic_event_fields(extra_event),
      economic_resource: economic_resource_fields(extra_resource)
    ]
  end

  def economic_event_query(options \\ []) do
    options = Keyword.put_new(options, :id_type, :id)
    gen_query(:id, &economic_event_subquery/1, options)
  end

  def economic_event_subquery(options \\ []) do
    gen_subquery(:id, :economic_event, &economic_event_fields/1, options)
  end

  def economic_events_subquery(options \\ []) do
    fields = Keyword.get(options, :fields, [])
    fields = fields ++ economic_event_fields(fields)
    field(:economic_events, [{:fields, fields} | options])
  end

  def economic_events_query(options \\ []) do
    gen_query(&economic_events_subquery/1, options)
  end

  def economic_events_pages_subquery(options \\ []) do
    args = [
      after: var(:economic_events_after),
      before: var(:economic_events_before),
      limit: var(:economic_events_limit)
    ]

    page_subquery(
      :economic_events_pages,
      &economic_event_fields/1,
      [{:args, args} | options]
    )
  end

  def economic_events_pages_query(options \\ []) do
    params =
      [
        economic_events_after: list_type(:cursor),
        economic_events_before: list_type(:cursor),
        economic_events_limit: :int
      ] ++ Keyword.get(options, :params, [])

    gen_query(&economic_events_pages_subquery/1, [{:params, params} | options])
  end

  def create_economic_event_mutation(options \\ []) do
    # event without any new resource
    [event: type!(:economic_event_create_params)]
    |> gen_mutation(&create_economic_event_submutation/1, options)
  end

  def create_economic_event_submutation(options \\ []) do
    [event: var(:event)]
    |> gen_submutation(:create_economic_event, &economic_event_response_fields/1, options)
  end

  def create_economic_event_mutation_without_new_inventoried_resource(event_options, resource_options) do
    # event with a resource
    [
      event: type!(:economic_event_create_params)
    ]
    |> gen_mutation(&create_economic_event_submutation_without_new_inventoried_resource/2, event_options, resource_options)
  end

  def create_economic_event_submutation_without_new_inventoried_resource(event_options, resource_options) do
    [event: var(:event)]
    |> gen_submutation(
      :create_economic_event,
      &economic_event_response_fields/2,
      event_options,
      resource_options
    )
  end

  def create_economic_event_mutation(event_options, resource_options) do
    # event with a resource
    [
      event: type!(:economic_event_create_params),
      new_inventoried_resource: type!(:economic_resource_create_params)
    ]
    |> gen_mutation(&create_economic_event_submutation/2, event_options, resource_options)
  end

  def create_economic_event_submutation(event_options, resource_options) do
    [event: var(:event), new_inventoried_resource: var(:new_inventoried_resource)]
    |> gen_submutation(
      :create_economic_event,
      &economic_event_response_fields/2,
      event_options,
      resource_options
    )
  end

  def update_economic_event_mutation(options \\ []) do
    [economic_event: type!(:economic_event_update_params)]
    |> gen_mutation(&update_economic_event_submutation/1, options)
  end

  def update_economic_event_submutation(options \\ []) do
    [economic_event: var(:economic_event)]
    |> gen_submutation(:update_economic_event, &economic_event_response_fields/1, options)
  end

  def delete_economic_event_mutation(options \\ []) do
    [id: type!(:id)]
    |> gen_mutation(&delete_economic_event_submutation/1, options)
  end

  def delete_economic_event_submutation(_options \\ []) do
    field(:delete_economic_event, args: [id: var(:id)])
  end

  def economic_resource_fields(extra \\ []) do
    extra ++ ~w(id name note tracking_identifier)a
  end

  def economic_resource_response_fields(extra \\ []) do
    [economic_resource: economic_resource_fields(extra)]
  end

  def economic_resource_query(options \\ []) do
    options = Keyword.put_new(options, :id_type, :id)
    gen_query(:id, &economic_resource_subquery/1, options)
  end

  def economic_resource_subquery(options \\ []) do
    gen_subquery(:id, :economic_resource, &economic_resource_fields/1, options)
  end

  def economic_resources_subquery(options \\ []) do
    fields = Keyword.get(options, :fields, [])
    fields = fields ++ economic_resource_fields(fields)
    field(:economic_resources, [{:fields, fields} | options])
  end

  def economic_resources_query(options \\ []) do
    gen_query(&economic_resources_subquery/1, options)
  end

  def economic_resources_pages_subquery(options \\ []) do
    args = [
      after: var(:economic_resources_after),
      before: var(:economic_resources_before),
      limit: var(:economic_resources_limit)
    ]

    page_subquery(
      :economic_resources_pages,
      &economic_resource_fields/1,
      [{:args, args} | options]
    )
  end

  def economic_resources_pages_query(options \\ []) do
    params =
      [
        economic_resources_after: list_type(:cursor),
        economic_resources_before: list_type(:cursor),
        economic_resources_limit: :int
      ] ++ Keyword.get(options, :params, [])

    gen_query(&economic_resources_pages_subquery/1, [{:params, params} | options])
  end
end
