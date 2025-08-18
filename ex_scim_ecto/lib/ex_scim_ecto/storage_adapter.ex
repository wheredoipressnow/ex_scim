defmodule ExScimEcto.StorageAdapter do
  @moduledoc """
  Ecto-based implementation of `ExScim.Storage.Adapter`.

  Expects the following in your application config:

      config :ex_scim,
        storage_repo: MyApp.Repo,
        user_model: MyApp.Accounts.User
        group_model: MyApp.Groups.Group

  """

  @behaviour ExScim.Storage.Adapter

  defp repo, do: Application.fetch_env!(:ex_scim, :storage_repo)
  defp schema, do: Application.fetch_env!(:ex_scim, :user_model)
  defp group_schema, do: Application.fetch_env!(:ex_scim, :group_model)

  @impl true
  def get_user(id) do
    case repo().get(schema(), id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  @impl true
  def get_user_by_username(username) do
    get_by(:user_name, username)
  end

  @impl true
  def get_user_by_external_id(external_id) do
    get_by(:external_id, external_id)
  end

  defp get_by(field, value) do
    case repo().get_by(schema(), [{field, value}]) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  @impl true
  def list_users(filter_ast, sort_opts, pagination_opts) do
    import Ecto.Query

    query =
      from(u in schema())
      |> ExScimEcto.QueryFilter.apply_filter(filter_ast)
      |> apply_sorting(sort_opts)
      |> apply_pagination(pagination_opts)

    users = repo().all(query)

    # Get total count for pagination
    count_query =
      from(u in schema())
      |> ExScimEcto.QueryFilter.apply_filter(filter_ast)

    total = repo().aggregate(count_query, :count)

    {:ok, users, total}
  end

  @impl true
  def create_user(domain_user) when is_struct(domain_user) do
    create_user(Map.from_struct(domain_user))
  end

  def create_user(domain_user) when is_map(domain_user) do
    # Domain user struct is already validated by Users context
    changeset = schema().changeset(schema().__struct__(), domain_user)

    case repo().insert(changeset) do
      {:ok, user} -> {:ok, user}
      error -> error
    end
  end

  @impl true
  def update_user(id, domain_user) do
    with {:ok, existing} <- get_user(id) do
      # Domain user struct is already validated by Users context
      changeset = schema().changeset(existing, Map.from_struct(domain_user))

      case repo().update(changeset) do
        {:ok, updated} -> {:ok, updated}
        error -> error
      end
    end
  end

  @impl true
  def delete_user(id) do
    with {:ok, user} <- get_user(id),
         {:ok, _} <- repo().delete(user) do
      :ok
    else
      {:error, _} = err -> err
    end
  end

  @impl true
  def user_exists?(id) do
    repo().get(schema(), id) != nil
  end

  # Group operations
  @impl true
  def get_group(id) do
    case repo().get(group_schema(), id) do
      nil -> {:error, :not_found}
      group -> {:ok, group}
    end
  end

  @impl true
  def get_group_by_display_name(display_name) do
    get_group_by(:display_name, display_name)
  end

  @impl true
  def get_group_by_external_id(external_id) do
    get_group_by(:external_id, external_id)
  end

  defp get_group_by(field, value) do
    case repo().get_by(group_schema(), [{field, value}]) do
      nil -> {:error, :not_found}
      group -> {:ok, group}
    end
  end

  @impl true
  def list_groups(filter_ast, sort_opts, pagination_opts) do
    import Ecto.Query

    query =
      from(g in group_schema())
      |> ExScimEcto.QueryFilter.apply_filter(filter_ast)
      |> apply_sorting(sort_opts)
      |> apply_pagination(pagination_opts)

    groups = repo().all(query)

    # Get total count for pagination
    count_query =
      from(g in group_schema())
      |> ExScimEcto.QueryFilter.apply_filter(filter_ast)

    total = repo().aggregate(count_query, :count)

    {:ok, groups, total}
  end

  @impl true
  def create_group(domain_group) when is_struct(domain_group) do
    create_group(Map.from_struct(domain_group))
  end

  def create_group(domain_group) when is_map(domain_group) do
    changeset = group_schema().changeset(group_schema().__struct__(), domain_group)

    case repo().insert(changeset) do
      {:ok, group} -> {:ok, group}
      error -> error
    end
  end

  @impl true
  def update_group(id, domain_group) do
    with {:ok, existing} <- get_group(id) do
      changeset = group_schema().changeset(existing, Map.from_struct(domain_group))

      case repo().update(changeset) do
        {:ok, updated} -> {:ok, updated}
        error -> error
      end
    end
  end

  @impl true
  def delete_group(id) do
    with {:ok, group} <- get_group(id),
         {:ok, _} <- repo().delete(group) do
      :ok
    else
      {:error, _} = err -> err
    end
  end

  @impl true
  def group_exists?(id) do
    repo().get(group_schema(), id) != nil
  end

  # Private helper functions

  defp apply_sorting(query, []), do: query

  defp apply_sorting(query, sort_opts) do
    import Ecto.Query

    case Keyword.get(sort_opts, :sort_by) do
      {sort_field, sort_direction} when is_binary(sort_field) ->
        field_atom = String.to_existing_atom(sort_field)

        case sort_direction do
          :desc -> order_by(query, [u], desc: field(u, ^field_atom))
          _ -> order_by(query, [u], asc: field(u, ^field_atom))
        end

      _ ->
        query
    end
  end

  defp apply_pagination(query, []), do: query

  defp apply_pagination(query, pagination_opts) do
    import Ecto.Query

    start_index = Keyword.get(pagination_opts, :start_index, 1)
    count = Keyword.get(pagination_opts, :count, 20)

    query
    |> offset(^(start_index - 1))
    |> limit(^count)
  end
end
