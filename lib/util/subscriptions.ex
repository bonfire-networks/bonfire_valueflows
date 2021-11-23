# SPDX-License-Identifier: AGPL-3.0-only
if Code.ensure_loaded?(Bonfire.GraphQL) do
defmodule ValueFlows.GraphQL.Subscriptions do
  use Absinthe.Schema.Notation

  object :valueflows_subscriptions do

    field :intent_created, :intent do
      arg :context, :string

      # The topic function is used to determine what topic a given subscription
      # cares about based on its arguments. You can think of it as a way to tell the
      # difference between
      # subscription {
      #   intentCreated(context: "a_context") { id name }
      # }
      #
      # and without context to get all created intents
      #
      # subscription {
      #   intentCreated { id name }
      # }
      #
      # If needed, you can also provide a list of topics:
      #   {:ok, topic: ["context_1", "context_2"]}
      config fn args, _ ->
        {:ok, topic: Map.get(args, :context, :all)}
      end

      # The below can tell Absinthe to run any subscriptions with this field every time the :create_intent mutation happens. It also has a topic function used to find what subscriptions care about this particular comment
      # Alternatively, we trigger it manually: `Absinthe.Subscription.publish(Bonfire.Web.Endpoint, intent, intent_created: "absinthe-graphql/absinthe")`
      # trigger :create_intent, topic: fn intent ->
      #   intent.context_id
      # end

      # resolve fn intent, _, _ ->
      #   # this function is often not actually necessary, as the default resolver
      #   # for subscription functions will just do what we're doing here.
      #   # The point is, subscription resolvers receive whatever value triggers
      #   # the subscription, in our case a comment.
      #   {:ok, intent}
      # end
    end
  end
end
end
