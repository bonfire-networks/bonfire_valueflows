# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Proposal.Proposals do
  import Bonfire.Common.Utils, only: [maybe_put: 3, attr_get_id: 2, maybe: 2]

  import Bonfire.Common.Config, only: [repo: 0]
  # alias Bonfire.GraphQL
  alias Bonfire.GraphQL.{Fields, Page}



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

  @spec one_proposed_intent(filters :: [any]) :: {:ok, ProposedIntent.t()} | {:error, term}
  def one_proposed_intent(filters),
    do: repo().single(ProposedIntentQueries.query(ProposedIntent, filters))

  @spec one_proposed_to(filters :: [any]) :: {:ok, ProposedTo.t()} | {:error, term}
  def one_proposed_to(filters),
    do: repo().single(ProposedToQueries.query(ProposedTo, filters))

  @doc """
  Retrieves a list of them by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def many(filters \\ []), do: {:ok, repo().many(Queries.query(Proposal, filters))}

  @spec many_proposed_intents(filters :: [any]) :: {:ok, [ProposedIntent.t()]} | {:error, term}
  def many_proposed_intents(filters \\ []),
    do: {:ok, repo().many(ProposedIntentQueries.query(ProposedIntent, filters))}

  @spec many_proposed_to(filters :: [any]) :: {:ok, [ProposedTo]} | {:error, term}
  def many_proposed_to(filters \\ []),
    do: {:ok, repo().many(ProposedToQueries.query(ProposedTo, filters))}

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
    Bonfire.GraphQL.Pagination.pages(
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

  @spec propose_intent(Proposal.t(), Intent.t(), map) ::
          {:ok, ProposedIntent.t()} | {:error, term}
  def propose_intent(%Proposal{} = proposal, %Intent{} = intent, attrs) do
    repo().insert(ProposedIntent.changeset(proposal, intent, attrs))
  end

  @spec delete_proposed_intent(ProposedIntent.t()) :: {:ok, ProposedIntent.t()} | {:error, term}
  def delete_proposed_intent(%ProposedIntent{} = proposed_intent) do
    Bonfire.Repo.Delete.soft_delete(proposed_intent)
  end

  # if you like it then you should put a ring on it
  @spec propose_to(any, Proposal.t()) :: {:ok, ProposedTo.t()} | {:error, term}
  def propose_to(proposed_to, %Proposal{} = proposed) do
    repo().insert(ProposedTo.changeset(proposed_to, proposed))
  end

  @spec delete_proposed_to(ProposedTo.t()) :: {:ok, ProposedTo.t()} | {:error, term}
  def delete_proposed_to(proposed_to), do: Bonfire.Repo.Delete.soft_delete(proposed_to)

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
    ValueFlows.Util.Federation.ap_publish_activity(activity_name, :proposal, thing, 3, [
      :published_in
    ])
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
