defmodule ExScimPhoenix.Controller.GroupController do
  @moduledoc """
  SCIM 2.0 Group Controller with configurable storage and group types.
  """

  use Phoenix.Controller, formats: [:json]
  require Logger
  import ExScimPhoenix.ErrorResponse

  alias ExScim.Operations.Groups

  plug(
    ExScimPhoenix.Plug.RequireScopes,
    [scopes: ["scim:read"]] when action in [:index, :show, :search]
  )

  plug(
    ExScimPhoenix.Plug.RequireScopes,
    [scopes: ["scim:write"]] when action in [:create, :update, :patch, :delete]
  )

  @scim_list_response_schema "urn:ietf:params:scim:api:messages:2.0:ListResponse"

  # Default pagination values
  @default_start_index 1
  @default_count 20
  @max_count 200

  def index(conn, params) do
    with {:ok, parsed_params} <- parse_list_params(params),
         {:ok, groups, total_results} <- Groups.list_groups_scim(parsed_params) do
      response = %{
        "schemas" => [@scim_list_response_schema],
        "totalResults" => total_results,
        "startIndex" => parsed_params.start_index,
        "itemsPerPage" => length(groups),
        "Resources" => groups
      }

      json(conn, response)
    else
      {:error, reason} ->
        send_scim_error(conn, :bad_request, :invalid_filter, "Invalid query: #{reason}")
    end
  end

  def show(conn, %{"id" => id}) do
    case Groups.get_group(id) do
      {:ok, group} ->
        json(conn, group)

      {:error, :not_found} ->
        send_scim_error(conn, :not_found, :not_found, "Group #{id} not found")

      {:error, reason} ->
        Logger.error("Error retrieving group #{id}: #{inspect(reason)}")
        send_scim_error(conn, :internal_server_error, :internal_error, "Internal server error")
    end
  end

  def create(conn, group_params) do
    case Groups.create_group_from_scim(group_params) do
      {:ok, group} ->
        location = get_in(group, ["meta", "location"])

        conn
        |> put_status(:created)
        |> put_resp_header("location", location)
        |> put_resp_header("etag", get_in(group, ["meta", "etag"]))
        |> json(group)

      {:error, :conflict} ->
        send_scim_error(conn, :conflict, :uniqueness, "Group already exists")

      {:error, errors} when is_list(errors) ->
        send_validation_errors(conn, errors)

      {:error, reason} ->
        Logger.error("Error creating group: #{inspect(reason)}")
        send_scim_error(conn, :internal_server_error, :internal_error, "Internal server error")
    end
  end

  def update(conn, %{"id" => id} = group_params) do
    # Remove id from params to avoid conflicts
    group_params = Map.delete(group_params, "id")

    case Groups.update_group_from_scim(id, group_params) do
      {:ok, group} ->
        conn
        |> put_resp_header("etag", get_in(group, ["meta", "etag"]))
        |> json(group)

      {:error, :not_found} ->
        send_scim_error(conn, :not_found, :not_found, "Group #{id} not found")

      {:error, :conflict} ->
        send_scim_error(conn, :conflict, :uniqueness, "Group data conflicts with existing group")

      {:error, errors} when is_list(errors) ->
        send_validation_errors(conn, errors)

      {:error, reason} ->
        Logger.error("Error updating group #{id}: #{inspect(reason)}")
        send_scim_error(conn, :internal_server_error, :internal_error, "Internal server error")
    end
  end

  def patch(conn, %{"id" => id} = patch_params) do
    # Remove id from params to avoid conflicts
    patch_params = Map.delete(patch_params, "id")

    case Groups.patch_group_from_scim(id, patch_params) do
      {:ok, group} ->
        conn
        |> put_resp_header("etag", get_in(group, ["meta", "etag"]))
        |> json(group)

      {:error, :not_found} ->
        send_scim_error(conn, :not_found, :not_found, "Group #{id} not found")

      {:error, :invalid_patch_operation} ->
        send_scim_error(conn, :bad_request, :invalid_syntax, "Invalid patch operation")

      {:error, :no_target} ->
        send_scim_error(
          conn,
          :bad_request,
          :no_target,
          "Path attribute did not yield a valid target"
        )

      {:error, :invalid_path} ->
        send_scim_error(
          conn,
          :bad_request,
          :invalid_path,
          "Path attribute is invalid or malformed"
        )

      {:error, errors} when is_list(errors) ->
        send_validation_errors(conn, errors)

      {:error, reason} ->
        Logger.error("Error patching group #{id}: #{inspect(reason)}")
        send_scim_error(conn, :internal_server_error, :internal_error, "Internal server error")
    end
  end

  def delete(conn, %{"id" => id}) do
    case Groups.delete_group(id) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        send_scim_error(conn, :not_found, :not_found, "Group #{id} not found")

      {:error, reason} ->
        Logger.error("Error deleting group #{id}: #{inspect(reason)}")
        send_scim_error(conn, :internal_server_error, :internal_error, "Internal server error")
    end
  end

  defp parse_list_params(params) do
    with {:ok, start_index} <- parse_integer_param(params, "startIndex", @default_start_index),
         {:ok, count} <- parse_integer_param(params, "count", @default_count),
         {:ok, validated_count} <- validate_count(count),
         {:ok, filter} <- parse_filter_param(params),
         {:ok, attributes} <- parse_attributes_param(params, "attributes"),
         {:ok, excluded_attributes} <- parse_attributes_param(params, "excludedAttributes"),
         {:ok, sort_by} <- parse_sort_param(params, "sortBy"),
         {:ok, sort_order} <- parse_sort_order_param(params, "sortOrder") do
      parsed_params = %{
        start_index: start_index,
        count: validated_count,
        filter: filter,
        attributes: attributes,
        excluded_attributes: excluded_attributes,
        sort_by: sort_by,
        sort_order: sort_order
      }

      {:ok, parsed_params}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_integer_param(params, key, default) do
    case Map.get(params, key) do
      nil ->
        {:ok, default}

      value when is_integer(value) ->
        {:ok, value}

      value when is_binary(value) ->
        case Integer.parse(value) do
          {int_value, ""} when int_value > 0 -> {:ok, int_value}
          _ -> {:error, "#{key} must be a positive integer"}
        end

      _ ->
        {:error, "#{key} must be a positive integer"}
    end
  end

  defp validate_count(count) when count > @max_count do
    {:ok, @max_count}
  end

  defp validate_count(count) when count >= 0 do
    {:ok, count}
  end

  defp validate_count(count) when count < 0 do
    # RFC 7644: "A negative value SHALL be interpreted as '0'"
    {:ok, 0}
  end

  defp validate_count(_count) do
    {:error, "count must be a non-negative integer"}
  end

  defp parse_filter_param(params) do
    case Map.get(params, "filter") do
      nil ->
        {:ok, nil}

      filter when is_binary(filter) ->
        case ExScim.Parser.Filter.filter(filter) do
          {:ok, [ast], "", _, _, _} ->
            {:ok, ast}

          {:error, reason, _rest, _context, line, column} ->
            {:error, "Invalid filter syntax at line #{line}, column #{column}: #{reason}"}
        end

      _ ->
        {:error, "filter must be a string"}
    end
  end

  defp parse_attributes_param(params, key) do
    case Map.get(params, key) do
      nil ->
        {:ok, []}

      attributes when is_binary(attributes) ->
        attribute_list =
          attributes
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        {:ok, attribute_list}

      _ ->
        {:error, "#{key} must be a comma-separated string"}
    end
  end

  defp parse_sort_param(params, key) do
    case Map.get(params, key) do
      nil -> {:ok, nil}
      sort_field when is_binary(sort_field) -> {:ok, sort_field}
      _ -> {:error, "#{key} must be a string"}
    end
  end

  defp parse_sort_order_param(params, key) do
    case Map.get(params, key) do
      nil -> {:ok, :ascending}
      "ascending" -> {:ok, :ascending}
      "descending" -> {:ok, :descending}
      _ -> {:error, "#{key} must be 'ascending' or 'descending'"}
    end
  end
end
