# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Proposal.Proposals do
  use Bonfire.Common.Utils, only: [maybe_put: 3, attr_get_id: 2, maybe: 2]

  import Bonfire.Common.Config, only: [repo: 0]
  # alias Bonfire.API.GraphQL
  alias Bonfire.API.GraphQL.{Fields, Page}

  alias ValueFlows.Proposal
  alias ValueFlows.Proposal

  alias ValueFlows.Proposal.{
    ProposedTo,
    ProposedToQueries,
    ProposedIntentQueries,
    ProposedIntent,
    Queries
  }

  alias ValueFlows.Planning.Intent

  def federation_module, do: ["ValueFlows:Proposal", "Proposal"]

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  @doc """
  Retrieves a single one by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def one(filters), do: repo().single(Queries.query(Proposal, filters))

  @doc """
  Retrieves a list of them by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def many(filters \\ []), do: {:ok, repo().many(Queries.query(Proposal, filters))}


  def fields(group_fn, filters \\ [])
      when is_function(group_fn, 1) do
    {:ok, fields} = many(filters)
    {:ok, Fields.new(fields, group_fn)}
  end

  @doc """
  Retrieves an Page of proposals according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(Proposal, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- repo().transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of proposals according to various filters

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
    Bonfire.API.GraphQL.Pagination.pages(
      Queries,
      Proposal,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end

  def preload_all(proposal) do
    repo().preload(proposal, [
      :creator,
      :eligible_location,
      # pointers, not supported
      :context
    ])
  end

  ## mutations

  @spec create(any(), attrs :: map) :: {:ok, Proposal.t()} | {:error, Changeset.t()}
  def create(%{} = creator, attrs) when is_map(attrs) do
    attrs = prepare_attrs(attrs)

    repo().transact_with(fn ->
      with {:ok, proposal} <- repo().insert(Proposal.create_changeset(creator, attrs)),
           act_attrs = %{verb: "created", is_local: true},
           {:ok, activity} <- ValueFlows.Util.publish(creator, :propose, proposal) do
        indexing_object_format(proposal) |> ValueFlows.Util.index_for_search()
        {:ok, preload_all(proposal)}
      end
    end)
  end

  # TODO: take the user who is performing the update
  @spec update(%Proposal{}, attrs :: map) :: {:ok, Proposal.t()} | {:error, Changeset.t()}
  def update(%Proposal{} = proposal, attrs) do
    attrs = prepare_attrs(attrs)

    repo().transact_with(fn ->
      with {:ok, proposal} <- repo().update(Proposal.update_changeset(proposal, attrs)),
           {:ok, _} <- ValueFlows.Util.publish(proposal, :update) do
        {:ok, proposal}
      end
    end)
  end

  def soft_delete(%Proposal{} = proposal) do
    repo().transact_with(fn ->
      with {:ok, proposal} <- Bonfire.Repo.Delete.soft_delete(proposal),
           {:ok, _} <- ValueFlows.Util.publish(proposal, :deleted) do
        {:ok, proposal}
      end
    end)
  end

  def indexing_object_format(obj) do

    # image = ValueFlows.Util.image_url(obj)

    %{
      "index_type" => "ValueFlows.Proposal",
      "id" => obj.id,
      # "url" => obj.canonical_url,
      # "icon" => icon,
      "name" => obj.name,
      "summary" => Map.get(obj, :note),
      "published_at" => obj.published_at,
      "creator" => ValueFlows.Util.indexing_format_creator(obj)
      # "index_instance" => URI.parse(obj.canonical_url).host, # home instance of object
    }
  end

  def ap_publish_activity(activity_name, thing) do
    ValueFlows.Util.Federation.ap_publish_activity(activity_name, :proposal, thing, 4, [
      :published_in
    ])
  end


  def ap_receive_activity(creator, activity, %{data: %{"publishes" => proposed_intents_attrs}} = object) when is_list(proposed_intents_attrs) and length(proposed_intents_attrs)>0 do
    IO.inspect(object, label: "ap_receive_activity - handle Proposal with nested ProposedIntent (and usually Intent too)")

    proposal_attrs = object |> Utils.maybe_to_map() |> pop_in([:data, "publishes"]) |> elem(1) # remove nested objects to avoid double-creations

    with {:ok, proposal} <- ValueFlows.Util.Federation.ap_receive_activity(creator, activity, proposal_attrs, &create/2) do

      proposed_intents = for a_proposed_intent_attrs <- proposed_intents_attrs do

        a_proposed_intent_attrs = a_proposed_intent_attrs |> Map.put(:published_in, proposal)

        with {:ok, proposed_intent} <- ValueFlows.Util.Federation.create_nested_object(creator, a_proposed_intent_attrs, proposal) do
          proposed_intent
        end
      end

      {:ok, proposal |> Map.put(:publishes, proposed_intents)}
    end
  end

  def ap_receive_activity(creator, activity, object) do
    IO.inspect(object, label: "ap_receive_activity - handle simple Proposal")
    ValueFlows.Util.Federation.ap_receive_activity(creator, activity, object, &create/2)
  end

  defp prepare_attrs(attrs) do
    attrs
    |> maybe_put(
      :context_id,
      attrs |> Map.get(:in_scope_of) |> maybe(&List.first/1)
    )
    |> maybe_put(:eligible_location_id, attr_get_id(attrs, :eligible_location))
  end
end
