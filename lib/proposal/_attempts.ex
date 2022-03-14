  # def ap_object_format_attempt1(obj) do
  #   obj = preloads(obj)
  #
  #   # image = ValueFlows.Util.image_url(obj)

  #   Map.merge(
  #     %{
  #       "type" => "ValueFlows:Proposal",
  #       # "canonicalUrl" => obj.canonical_url,
  #       # "icon" => icon,
  #       "published" => obj.has_beginning
  #     },
  #     keys_transform(obj, "to_string")
  #   )
  # end

  # def graphql_get_proposal_attempt2(id) do
  #   query =
  #     Grumble.PP.to_string(
  #       Grumble.field(
  #         :proposal,
  #         args: [id: Grumble.var(:id)],
  #         fields: ValueFlows.Simulate.proposal_fields(eligible_location: [:name])
  #       )
  #     )
  #     |> IO.inspect()

  #   with {:ok, g} <-
  #          """
  #           query ($id: ID) {
  #              #{query}
  #            }
  #          """
  #          |> Absinthe.run(@schema, variables: %{"id" => id}) do
  #     g |> Map.get(:data) |> Map.get("proposal")
  #   end
  # end

  # def ap_object_prepare_attempt2(id) do
  #   with obj <- graphql_get_proposal_attempt2(id) do
  #     Map.merge(
  #       %{
  #         "type" => "ValueFlows:Proposal"
  #         # "canonicalUrl" => obj.canonical_url,
  #         # "icon" => icon,
  #         # "published" => obj.hasBeginning
  #       },
  #       obj
  #     )
  #   end
  # end


# def graphql_document_for(schema, type, nesting, override_fun \\ []) do
  #   schema
  #   |> Bonfire.API.GraphQL.QueryHelper.fields_for(type, nesting)
  #   # |> IO.inspect()
  #   |> Bonfire.API.GraphQL.QueryHelper.apply_overrides(override_fun)
  #   |> Bonfire.API.GraphQL.QueryHelper.format_fields(type, 10, schema)
  #   |> List.to_string()
  # end


# def graphql_get_proposal_attempt3(id) do
  #   query = Bonfire.API.GraphQL.QueryHelper.document_for(@schema, :proposal, 4, &fields_filter/1)
  #   IO.inspect(query)

  #   with {:ok, g} <-
  #          """
  #           query ($id: ID) {
  #             proposal(id: $id) {
  #               #{query}
  #             }
  #           }
  #          """
  #          |> Absinthe.run(@schema, variables: %{"id" => id}) do
  #     IO.inspect(g)
  #     g |> Map.get(:data) |> Map.get("proposal")
  #   end
  # end
