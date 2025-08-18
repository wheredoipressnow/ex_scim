defmodule ExScimPhoenix.Plug.RequireScopes do
  @moduledoc """
  Ensures SCIM principal has required scopes and allowed types.
  """

  import Plug.Conn
  alias ExScim.Auth.Principal

  def init(opts) do
    %{
      scopes: Keyword.get(opts, :scopes, []),
      types: Keyword.get(opts, :types, [:user, :client])
    }
  end

  def call(conn, %{scopes: required_scopes, types: allowed_types}) do
    case conn.assigns[:scim_principal] do
      %Principal{type: type, scopes: scopes} ->
        if type in allowed_types do
          case authorize_scopes(scopes, required_scopes) do
            {:ok, _} ->
              conn

            {:error, :insufficient_scope} ->
              conn
              |> ExScimPhoenix.ErrorResponse.send_scim_error(
                :forbidden,
                :insufficient_scope,
                "Missing required scope(s): #{Enum.join(required_scopes, ", ")}"
              )
              |> halt()
          end
        else
          conn
          |> ExScimPhoenix.ErrorResponse.send_scim_error(
            :forbidden,
            :invalid_target,
            "This endpoint is not available for principals of type #{inspect(type)}"
          )
          |> halt()
        end

      _ ->
        conn
        |> ExScimPhoenix.ErrorResponse.send_scim_error(
          :unauthorized,
          :no_authn,
          "Authentication required"
        )
        |> halt()
    end
  end

  defp authorize_scopes(scopes, required_scopes) when is_list(required_scopes) do
    if Enum.all?(required_scopes, &(&1 in scopes)) do
      {:ok, scopes}
    else
      {:error, :insufficient_scope}
    end
  end

  defp authorize_scopes(_scopes, _required_scopes), do: {:error, :invalid_client}
end
