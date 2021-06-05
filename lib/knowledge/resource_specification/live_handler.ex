defmodule ValueFlows.Knowledge.ResourceSpecification.LiveHandler do
  use Bonfire.Web, :live_handler

  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.Knowledge.ResourceSpecification.ResourceSpecifications

  def changeset(attrs \\ %{}) do
    ResourceSpecification.validate_changeset(attrs)
  end

  def handle_event("create", attrs, socket) do
    with obj_attrs <- attrs
                      |> IO.inspect()
                      |> Map.merge(attrs["resource_spec"])
                      |> input_to_atoms()
                      # |> Map.get(:resource_spec)
                      |> ResourceSpecifications.prepare_attrs()
                      |> IO.inspect(),
    %{valid?: true} = cs <- changeset(obj_attrs),
    {:ok, resource_spec} <- ResourceSpecifications.create(e(socket.assigns, :current_user, nil), obj_attrs) do
      IO.inspect(resource_spec)
      {:noreply, socket |> push_redirect(to: e(attrs, "redirect_after", "/resource_spec/")<>resource_spec.id)}
    end
  end


  def handle_event("autocomplete", search, socket) when is_binary(search) do

    matches = with {:ok, matches} <- ResourceSpecifications.many(autocomplete: search) do
      IO.inspect(matches)
      matches |> Enum.map(&to_tuple/1)
    else
      _ -> []
    end
    # IO.inspect(matches)

    options = matches ++ [{"Create a new resource specification called: "<>search, search}]

    {:noreply, socket |> cast_self(resource_specifications_autocomplete: options) }
  end


  def handle_event("select", %{"id" => select_resource_spec, "name"=> name} = attrs, socket) when is_binary(select_resource_spec) do
    # IO.inspect(socket)

    selected = if !is_ulid?(select_resource_spec), do: create_in_autocomplete(e(socket.assigns, :current_user, nil), select_resource_spec), else: {name, select_resource_spec}

    IO.inspect(selected)
    {:noreply, socket |> cast_self(resource_specification_selected: [selected])}
  end

  def to_tuple(resource_spec) do
    {resource_spec.name, resource_spec.id}
  end

  def create_in_autocomplete(creator, name) do
    with {:ok, rs} <- ResourceSpecifications.create(creator, %{name: name}) do
      {rs.name, rs.id}
    end
  end


end
