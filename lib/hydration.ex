if Code.ensure_loaded?(Bonfire.API.GraphQL) do
defmodule ValueFlows.Hydration do

  import ValueFlows.Util.GraphQL
  alias Bonfire.API.GraphQL.CommonResolver




  def hydrate() do
    agent_fields = %{
      canonical_url: [
        resolve: &CommonResolver.canonical_url_edge/3
      ],
      display_username: [
        resolve: &CommonResolver.display_username_edge/3
      ],
      proposals: [
        resolve: &ValueFlows.Proposal.GraphQL.agent_proposals/3
      ],
      intents: [
        resolve: &ValueFlows.Planning.Intent.GraphQL.agent_intents/3
      ],
      processes: [
        resolve: &ValueFlows.Process.GraphQL.creator_processes/3
      ],
      economic_events: [
        resolve: &ValueFlows.EconomicEvent.GraphQL.agent_events/3
      ],
      inventoried_economic_resources: [
        resolve: &ValueFlows.EconomicResource.GraphQL.agent_resources/3
      ]
    }

    %{
      # Type extensions
      uri: [
        parse: &parse_cool_scalar/1,
        serialize: &serialize_cool_scalar/1
      ],
      agent: [
        resolve_type: &__MODULE__.agent_resolve_type/2
      ],
      production_flow_item: [
        resolve_type: &__MODULE__.production_flow_item_resolve_type/2
      ],
      accounting_scope: [
        resolve_type: &__MODULE__.resolve_context_type/2
      ],
      event_or_commitment: [
        resolve_type: &ValueFlows.Planning.Satisfaction.GraphQL.event_or_commitment_resolve_type/2
      ],
      person: agent_fields,
      organization: agent_fields,
      # person: [
      #   is_type_of: &ValueFlows.Agent.GraphQL.person_is_type_of/2
      # ],
      # organization: [
      #   is_type_of: &ValueFlows.Agent.GraphQL.organization_is_type_of/2
      # ],
      proposed_intent: %{
        publishes: [
          resolve: &ValueFlows.Proposal.ProposedIntentGraphQL.intent_in_proposal_edge/3
        ],
        published_in: [
          resolve: &ValueFlows.Proposal.ProposedIntentGraphQL.proposal_in_intent_edge/3
        ]
      },
      proposal: %{
        canonical_url: [
          resolve: &CommonResolver.canonical_url_edge/3
        ],
        in_scope_of: [
          resolve: &scope_edge/3
        ],
        eligible_location: [
          resolve: &ValueFlows.Proposal.GraphQL.eligible_location_edge/3
        ],
        publishes: [
          resolve: &ValueFlows.Proposal.ProposedIntentGraphQL.publishes_edge/3
        ],
        published_to: [
          resolve: &ValueFlows.Proposal.ProposedToGraphQL.published_to_edge/3
        ],
        # creator: [
        #   resolve: &UsersResolver.creator_edge/3
        # ]
      },
      proposed_to: %{
        proposed_to: [
          resolve: &ValueFlows.Proposal.ProposedToGraphQL.proposed_to_agent/3
        ],
        fetch_proposed_edge: [
          resolve: &ValueFlows.Proposal.ProposedToGraphQL.fetch_proposed_edge/3
        ]
      },
      intent: %{
        canonical_url: [
          resolve: &CommonResolver.canonical_url_edge/3
        ],
        provider: [
          resolve: &fetch_provider_edge/3
        ],
        receiver: [
          resolve: &fetch_receiver_edge/3
        ],
        action: [
          resolve: &ValueFlows.Knowledge.Action.GraphQL.action_edge/3
        ],
        at_location: [
          resolve: &at_location_edge/3
        ],
        in_scope_of: [
          resolve: &scope_edge/3
        ],
        image: [
          resolve: &image_content_url/3
        ],
        resource_classified_as: [
          resolve: &fetch_classifications_edge/3
        ],
        tags: [
          resolve: &tags_edges/3
        ],
        published_in: [
          resolve: &ValueFlows.Proposal.ProposedIntentGraphQL.published_in_edge/3
        ],
        resource_conforms_to: [
          resolve: &fetch_resource_conforms_to_edge/3
        ],
        resource_inventoried_as: [
          resolve: &ValueFlows.Planning.Intent.GraphQL.fetch_resource_inventoried_as_edge/3
        ],
        available_quantity: [
          resolve: &available_quantity_edge/3
        ],
        resource_quantity: [
          resolve: &resource_quantity_edge/3
        ],
        effort_quantity: [
          resolve: &effort_quantity_edge/3
        ],
        input_of: [
          resolve: &ValueFlows.Planning.Intent.GraphQL.fetch_input_of_edge/3
        ],
        output_of: [
          resolve: &ValueFlows.Planning.Intent.GraphQL.fetch_output_of_edge/3
        ],
        satisfied_by: [
          resolve: &ValueFlows.Planning.Intent.GraphQL.fetch_satisfied_by_edge/3
        ]
      },
      commitment: %{
        action: [
          resolve: &ValueFlows.Knowledge.Action.GraphQL.action_edge/3
        ],
        input_of: [
          resolve: &ValueFlows.Planning.Commitment.GraphQL.fetch_input_of_edge/3
        ],
        output_of: [
          resolve: &ValueFlows.Planning.Commitment.GraphQL.fetch_output_of_edge/3
        ],
        provider: [
          resolve: &fetch_provider_edge/3
        ],
        receiver: [
          resolve: &fetch_receiver_edge/3
        ],
        resource_conforms_to: [
          resolve: &fetch_resource_conforms_to_edge/3
        ],
        resource_inventoried_as: [
          resolve: &ValueFlows.Planning.Commitment.GraphQL.fetch_resource_inventoried_as_edge/3
        ],
        resource_quantity: [
          resolve: &resource_quantity_edge/3
        ],
        effort_quantity: [
          resolve: &effort_quantity_edge/3
        ],
        created: [
          resolve: &ValueFlows.Planning.Commitment.GraphQL.fetch_created/3
        ],
        in_scope_of: [
          resolve: &scope_edge/3
        ],
        at_location: [
          resolve: &at_location_edge/3
        ],
        tags: [
          resolve: &tags_edges/3
        ],
        satisfies: [
          resolve: &ValueFlows.Planning.Commitment.GraphQL.fetch_satisfies_edge/3
        ]
      },
      satisfaction: %{
        satisfies: [
          resolve: &ValueFlows.Planning.Satisfaction.GraphQL.fetch_satisfies_edge/3
        ],
        satisfied_by: [
          resolve: &ValueFlows.Planning.Satisfaction.GraphQL.fetch_satisfied_by_edge/3,
        ],
        resource_quantity: [
          resolve: &resource_quantity_edge/3
        ],
        effort_quantity: [
          resolve: &effort_quantity_edge/3
        ],
      },
      claim: %{
        action: [
          resolve: &ValueFlows.Knowledge.Action.GraphQL.action_edge/3
        ],
        provider: [
          resolve: &fetch_provider_edge/3
        ],
        receiver: [
          resolve: &fetch_receiver_edge/3
        ],
        resource_quantity: [
          resolve: &resource_quantity_edge/3
        ],
        effort_quantity: [
          resolve: &effort_quantity_edge/3
        ],
        resource_conforms_to: [
          resolve: &fetch_resource_conforms_to_edge/3
        ],
        triggered_by: [
          resolve: &ValueFlows.Claim.GraphQL.fetch_triggered_by_edge/3
        ],
        in_scope_of: [
          resolve: &scope_edge/3
        ],
        # creator: [
        #   resolve: &UsersResolver.creator_edge/3
        # ]
      },
      economic_event: %{
        canonical_url: [
          resolve: &CommonResolver.canonical_url_edge/3
        ],
        provider: [
          resolve: &fetch_provider_edge/3
        ],
        receiver: [
          resolve: &fetch_receiver_edge/3
        ],
        action: [
          resolve: &ValueFlows.Knowledge.Action.GraphQL.action_edge/3
        ],
        resource_conforms_to: [
          resolve: &fetch_resource_conforms_to_edge/3
        ],
        resource_quantity: [
          resolve: &resource_quantity_edge/3
        ],
        effort_quantity: [
          resolve: &effort_quantity_edge/3
        ],
        in_scope_of: [
          resolve: &scope_edge/3
        ],
        input_of: [
          resolve: &ValueFlows.EconomicEvent.GraphQL.fetch_input_of_edge/3
        ],
        output_of: [
          resolve: &ValueFlows.EconomicEvent.GraphQL.fetch_output_of_edge/3
        ],
        resource_inventoried_as: [
          resolve:
            &ValueFlows.EconomicEvent.GraphQL.fetch_resource_inventoried_as_edge/3
        ],
        to_resource_inventoried_as: [
          resolve:
            &ValueFlows.EconomicEvent.GraphQL.fetch_to_resource_inventoried_as_edge/3
        ],
        resource_classified_as: [
          resolve: &fetch_classifications_edge/3
        ],
        at_location: [
          resolve: &at_location_edge/3
        ],
        triggered_by: [
          resolve: &ValueFlows.EconomicEvent.GraphQL.fetch_triggered_by_edge/3
        ],
        tags: [
          resolve: &tags_edges/3
        ],
        trace: [
          resolve: &ValueFlows.EconomicEvent.GraphQL.trace/3
        ],
        track: [
          resolve: &ValueFlows.EconomicEvent.GraphQL.track/3
        ]
      },
      economic_resource: %{
        canonical_url: [
          resolve: &CommonResolver.canonical_url_edge/3
        ],
        state: [
          resolve: &ValueFlows.EconomicResource.GraphQL.fetch_state_edge/3
        ],
        in_scope_of: [
          resolve: &scope_edge/3
        ],
        classified_as: [
          resolve: &fetch_classifications_edge/3
        ],
        current_location: [
          resolve: &current_location_edge/3
        ],
        image: [
          resolve: &image_content_url/3
        ],
        available_quantity: [
          resolve: &available_quantity_edge/3
        ],
        accounting_quantity: [
          resolve: &accounting_quantity_edge/3
        ],
        onhand_quantity: [
          resolve: &onhand_quantity_edge/3
        ],
        primary_accountable: [
          resolve:
            &ValueFlows.EconomicResource.GraphQL.fetch_primary_accountable_edge/3
        ],
        unit_of_effort: [
          resolve: &ValueFlows.EconomicResource.GraphQL.fetch_unit_of_effort_edge/3
        ],
        contained_in: [
          resolve: &ValueFlows.EconomicResource.GraphQL.fetch_contained_in_edge/3
        ],
        conforms_to: [
          resolve: &ValueFlows.EconomicResource.GraphQL.fetch_conforms_to_edge/3
        ],
        tags: [
          resolve: &tags_edges/3
        ],
        trace: [
          resolve: &ValueFlows.EconomicResource.GraphQL.trace/3
        ],
        track: [
          resolve: &ValueFlows.EconomicResource.GraphQL.track/3
        ]
      },
      process: %{
        canonical_url: [
          resolve: &CommonResolver.canonical_url_edge/3
        ],
        in_scope_of: [
          resolve: &scope_edge/3
        ],
        classified_as: [
          resolve: &fetch_classifications_edge/3
        ],
        tags: [
          resolve: &tags_edges/3
        ],
        track: [
          resolve: &ValueFlows.Process.GraphQL.track/3
        ],
        trace: [
          resolve: &ValueFlows.Process.GraphQL.trace/3
        ],
        intended_inputs: [
          resolve: &ValueFlows.Process.GraphQL.intended_inputs/3
        ],
        intended_outputs: [
          resolve: &ValueFlows.Process.GraphQL.intended_outputs/3
        ],
        inputs: [
          resolve: &ValueFlows.Process.GraphQL.inputs/3
        ],
        outputs: [
          resolve: &ValueFlows.Process.GraphQL.outputs/3
        ],
        based_on: [
          resolve: &ValueFlows.Process.GraphQL.fetch_based_on_edge/3
        ]
      },
      resource_specification: %{
        default_unit_of_effort: [
          resolve:
            &ValueFlows.Knowledge.ResourceSpecification.GraphQL.fetch_default_unit_of_effort_edge/3
        ],
        image: [
          resolve: &image_content_url/3
        ],
        tags: [
          resolve: &tags_edges/3
        ],
        # conforming_resources: [
        #   resolve: %ValueFlows.Knowledge.ResourceSpecification.GraphQL.fetch_conforming_resources_edge/3
        # ]
      },

      value_calculation: %{
        value_unit: [
          resolve: &ValueFlows.ValueCalculation.GraphQL.value_unit_edge/3,
        ],
        action: [
          resolve: &ValueFlows.Knowledge.Action.GraphQL.action_edge/3
        ],
        value_action: [
          resolve: &ValueFlows.ValueCalculation.GraphQL.value_action_edge/3,
        ],
        resource_conforms_to: [
          resolve: &ValueFlows.ValueCalculation.GraphQL.resource_conforms_to_edge/3,
        ],
        value_resource_conforms_to: [
          resolve: &ValueFlows.ValueCalculation.GraphQL.value_resource_conforms_to_edge/3,
        ],
        in_scope_of: [
          resolve: &scope_edge/3,
        ],
      },

      # start Query resolvers
      value_flows_query: %{
        # Agents:
        agents: [
          resolve: &ValueFlows.Agent.GraphQL.all_agents/2
        ],
        # agents_pages: [
        #   resolve: &ValueFlows.Agent.GraphQL.agents/2
        # ],
        agent: [
          resolve: &ValueFlows.Agent.GraphQL.agent/2
        ],
        my_agent: [
          resolve: &ValueFlows.Agent.GraphQL.my_agent/2
        ],
        person: [
          resolve: &ValueFlows.Agent.GraphQL.person/2
        ],
        people: [
          resolve: &ValueFlows.Agent.GraphQL.all_people/2
        ],
        people_pages: [
          resolve: &ValueFlows.Agent.GraphQL.people/2
        ],
        organization: [
          resolve: &ValueFlows.Agent.GraphQL.organization/2
        ],
        organizations: [
          resolve: &ValueFlows.Agent.GraphQL.all_organizations/2
        ],
        organizations_pages: [
          resolve: &ValueFlows.Agent.GraphQL.organizations/2
        ],

        # Claim
        claim: [
          resolve: &ValueFlows.Claim.GraphQL.claim/2
        ],
        claims: [
          resolve: &ValueFlows.Claim.GraphQL.claims/2
        ],

        # Value Calculation
        value_calculation: [
          resolve: &ValueFlows.ValueCalculation.GraphQL.value_calculation/2
        ],
        value_calculations_pages: [
          resolve: &ValueFlows.ValueCalculation.GraphQL.value_calculations/2
        ],

        # Knowledge
        action: [
          resolve: &ValueFlows.Knowledge.Action.GraphQL.action/2
        ],
        actions: [
          resolve: &ValueFlows.Knowledge.Action.GraphQL.all_actions/2
        ],
        resource_specification: [
          resolve: &ValueFlows.Knowledge.ResourceSpecification.GraphQL.resource_spec/2
        ],
        resource_specifications: [
          resolve: &ValueFlows.Knowledge.ResourceSpecification.GraphQL.all_resource_specs/2
        ],
        resource_specifications_pages: [
          resolve: &ValueFlows.Knowledge.ResourceSpecification.GraphQL.resource_specs/2
        ],
        process_specification: [
          resolve: &ValueFlows.Knowledge.ProcessSpecification.GraphQL.process_spec/2
        ],
        process_specifications: [
          resolve: &ValueFlows.Knowledge.ProcessSpecification.GraphQL.all_process_specs/2
        ],

        # Observation
        economic_event: [
          resolve: &ValueFlows.EconomicEvent.GraphQL.event/2
        ],
        economic_events: [
          resolve: &ValueFlows.EconomicEvent.GraphQL.all_events/2
        ],
        economic_events_pages: [
          resolve: &ValueFlows.EconomicEvent.GraphQL.events/2
        ],
        economic_events_filtered: [
          resolve: &ValueFlows.EconomicEvent.GraphQL.events_filtered/2
        ],
        economic_resource: [
          resolve: &ValueFlows.EconomicResource.GraphQL.resource/2
        ],
        economic_resources: [
          resolve: &ValueFlows.EconomicResource.GraphQL.all_resources/2
        ],
        economic_resources_pages: [
          resolve: &ValueFlows.EconomicResource.GraphQL.resources/2
        ],
        economic_resources_filtered: [
          resolve: &ValueFlows.EconomicResource.GraphQL.resources_filtered/2
        ],
        process: [
          resolve: &ValueFlows.Process.GraphQL.process/2
        ],
        processes: [
          resolve: &ValueFlows.Process.GraphQL.all_processes/2
        ],
        processes_pages: [
          resolve: &ValueFlows.Process.GraphQL.processes/2
        ],

        # Planning
        intent: [
          resolve: &ValueFlows.Planning.Intent.GraphQL.intent/2
        ],
        intents: [
          resolve: &ValueFlows.Planning.Intent.GraphQL.intents_filtered/2
        ],
        intents_pages: [
          resolve: &ValueFlows.Planning.Intent.GraphQL.intents/2
        ],
        offers_pages: [
          resolve: &ValueFlows.Planning.Intent.GraphQL.offers/2
        ],
        needs_pages: [
          resolve: &ValueFlows.Planning.Intent.GraphQL.needs/2
        ],
        # intents_filtered: [
        #   resolve: &ValueFlows.Planning.Intent.GraphQL.intents_filtered/2
        # ],
        commitment: [
          resolve: &ValueFlows.Planning.Commitment.GraphQL.commitment/2
        ],
        commitments: [
          resolve: &ValueFlows.Planning.Commitment.GraphQL.commitments_filtered/2
        ],
        satisfaction: [
          resolve: &ValueFlows.Planning.Satisfaction.GraphQL.satisfaction/2
        ],
        satisfactions: [
          resolve: &ValueFlows.Planning.Satisfaction.GraphQL.satisfactions_filtered/2
        ],

        # Proposal
        proposal: [
          resolve: &ValueFlows.Proposal.GraphQL.proposal/2
        ],
        proposals: [
          resolve: &ValueFlows.Proposal.GraphQL.all_proposals/2
        ],
        proposals_pages: [
          resolve: &ValueFlows.Proposal.GraphQL.proposals/2
        ],
        proposals_filtered: [
          resolve: &ValueFlows.Proposal.GraphQL.proposals_filtered/2
        ]
      },

      # end Queries

      # start Mutation resolvers
      value_flows_mutation: %{
        create_commitment: [
          resolve: &ValueFlows.Planning.Commitment.GraphQL.create_commitment/2
        ],
        update_commitment: [
          resolve: &ValueFlows.Planning.Commitment.GraphQL.update_commitment/2
        ],
        delete_commitment: [
          resolve: &ValueFlows.Planning.Commitment.GraphQL.delete_commitment/2
        ],

        create_intent: [
          resolve: &ValueFlows.Planning.Intent.GraphQL.create_intent/2
        ],
        delete_intent: [
          resolve: &ValueFlows.Planning.Intent.GraphQL.delete_intent/2
        ],
        update_intent: [
          resolve: &ValueFlows.Planning.Intent.GraphQL.update_intent/2
        ],

        create_satisfaction: [
          resolve: &ValueFlows.Planning.Satisfaction.GraphQL.create/2
        ],
        delete_satisfaction: [
          resolve: &ValueFlows.Planning.Satisfaction.GraphQL.delete/2
        ],
        update_satisfaction: [
          resolve: &ValueFlows.Planning.Satisfaction.GraphQL.update/2
        ],

        create_claim: [
          resolve: &ValueFlows.Claim.GraphQL.create_claim/2
        ],
        create_proposal: [
          resolve: &ValueFlows.Proposal.GraphQL.create_proposal/2
        ],
        propose_intent: [
          resolve: &ValueFlows.Proposal.ProposedIntentGraphQL.propose_intent/2
        ],
        propose_to: [
          resolve: &ValueFlows.Proposal.ProposedToGraphQL.propose_to/2
        ],
        create_offer: [
          resolve: &ValueFlows.Planning.Intent.GraphQL.create_offer/2
        ],
        create_need: [
          resolve: &ValueFlows.Planning.Intent.GraphQL.create_need/2
        ],
        # create_action: [
        #   resolve: &ValueFlows.Knowledge.Action.GraphQL.create_action/2
        # ],
        update_claim: [
          resolve: &ValueFlows.Claim.GraphQL.update_claim/2
        ],
        update_proposal: [
          resolve: &ValueFlows.Proposal.GraphQL.update_proposal/2
        ],
        update_resource_specification: [
          resolve: &ValueFlows.Knowledge.ResourceSpecification.GraphQL.update_resource_spec/2
        ],
        update_process_specification: [
          resolve: &ValueFlows.Knowledge.ProcessSpecification.GraphQL.update_process_spec/2
        ],
        update_process: [
          resolve: &ValueFlows.Process.GraphQL.update_process/2
        ],
        delete_claim: [
          resolve: &ValueFlows.Claim.GraphQL.delete_claim/2
        ],
        delete_proposal: [
          resolve: &ValueFlows.Proposal.GraphQL.delete_proposal/2
        ],
        delete_resource_specification: [
          resolve: &ValueFlows.Knowledge.ResourceSpecification.GraphQL.delete_resource_spec/2
        ],
        delete_process_specification: [
          resolve: &ValueFlows.Knowledge.ProcessSpecification.GraphQL.delete_process_spec/2
        ],
        delete_process: [
          resolve: &ValueFlows.Process.GraphQL.delete_process/2
        ],
        delete_proposed_intent: [
          resolve: &ValueFlows.Proposal.ProposedIntentGraphQL.delete_proposed_intent/2
        ],
        delete_proposed_to: [
          resolve: &ValueFlows.Proposal.ProposedToGraphQL.delete_proposed_to/2
        ],
        create_resource_specification: [
          resolve: &ValueFlows.Knowledge.ResourceSpecification.GraphQL.create_resource_spec/2
        ],
        create_process_specification: [
          resolve: &ValueFlows.Knowledge.ProcessSpecification.GraphQL.create_process_spec/2
        ],
        create_process: [
          resolve: &ValueFlows.Process.GraphQL.create_process/2
        ],
        create_economic_event: [
          resolve: &ValueFlows.EconomicEvent.GraphQL.create_event/2
        ],
        update_economic_event: [
          resolve: &ValueFlows.EconomicEvent.GraphQL.update_event/2
        ],
        delete_economic_event: [
          resolve: &ValueFlows.EconomicEvent.GraphQL.delete_event/2
        ],
        update_economic_resource: [
          resolve: &ValueFlows.EconomicResource.GraphQL.update_resource/2
        ],
        create_person: [
          resolve: &ValueFlows.Agent.GraphQL.mutate_person/2
        ],
        update_person: [
          resolve: &ValueFlows.Agent.GraphQL.mutate_person/2
        ],
        delete_person: [
          resolve: &ValueFlows.Agent.GraphQL.mutate_person/2
        ],
        create_organization: [
          resolve: &ValueFlows.Agent.GraphQL.mutate_organization/2
        ],
        update_organization: [
          resolve: &ValueFlows.Agent.GraphQL.mutate_organization/2
        ],
        delete_organization: [
          resolve: &ValueFlows.Agent.GraphQL.mutate_organization/2
        ],
        create_value_calculation: [
          resolve: &ValueFlows.ValueCalculation.GraphQL.create_value_calculation/2,
        ],
        update_value_calculation: [
          resolve: &ValueFlows.ValueCalculation.GraphQL.update_value_calculation/2,
        ],
        delete_value_calculation: [
          resolve: &ValueFlows.ValueCalculation.GraphQL.delete_value_calculation/2,
        ],
      }
    }
  end

  # support for interface type
  @spec agent_resolve_type(%{agent_type: nil | :organization | :person}, any) ::
          :organization | :person
  def agent_resolve_type(%{agent_type: :person}, _), do: :person
  def agent_resolve_type(%{agent_type: :organization}, _), do: :organization
  # def agent_resolve_type(%ValueFlows.Util.org_schema(){}, _), do: :organization
  # def agent_resolve_type(%ValueFlows.Util.user_schema(){}, _), do: :person
  # def agent_resolve_type(_, _), do: :person
  def agent_resolve_type(%{__struct__: type}, _) do
    u= ValueFlows.Util.user_schema()
    o= ValueFlows.Util.org_schema()
    case type do
      u ->
        :person
      o ->
        :organization
      _ ->
        :person
    end
  end
  def resolve_context_type(_, _), do: :person # fallback

  # def person_is_type_of(_), do: true
  # def organization_is_type_of(_), do: true

  # def resolve_context_type(%ValueFlows.Util.user_schema(){}, _), do: :person
  # def resolve_context_type(%ValueFlows.Util.org_schema(){}, _), do: :organization
  # def resolve_context_type(%CommonsPub.Communities.Community{}, _), do: :community
  # def resolve_context_type(%CommonsPub.Collections.Collection{}, _), do: :collection
  # def resolve_context_type(_, _), do: :agent
  def resolve_context_type(%ValueFlows.Planning.Intent{}, _), do: :intent
  def resolve_context_type(%ValueFlows.Process{}, _), do: :process
  # TODO more
  def resolve_context_type(%{__struct__: type}, _) do
    u= ValueFlows.Util.user_schema()
    o= ValueFlows.Util.org_schema()
    # FIXME
    case type do
      u ->
        :person
      o ->
        :organization
    end
  end

  def resolve_context_type(_, _), do: :organization # fallback

  def production_flow_item_resolve_type(%ValueFlows.EconomicEvent{}, _), do: :economic_event
  def production_flow_item_resolve_type(%ValueFlows.EconomicResource{}, _), do: :economic_resource
  def production_flow_item_resolve_type(%ValueFlows.Process{}, _), do: :process
  def production_flow_item_resolve_type(_, _), do: :economic_event
end
end
