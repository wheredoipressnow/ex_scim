defmodule ExScimPhoenix.Controller.ServiceProviderConfigController do
  use Phoenix.Controller, formats: [:json]

  alias ExScim.Config

  plug(ExScimPhoenix.Plug.RequireScopes, [scopes: ["scim:read"]] when action in [:show])

  @doc """
  GET /scim/v2/ServiceProviderConfig - RFC 7643 Section 5
  """
  def show(conn, _params) do
    base_url = Config.base_url()
    bulk_config = get_bulk_config()

    config = %{
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig"],
      "documentationUri" => "#{base_url}/scim/docs",
      "patch" => %{
        "supported" => true
      },
      "bulk" => %{
        "supported" => bulk_config.supported,
        "maxOperations" => bulk_config.max_operations,
        "maxPayloadSize" => bulk_config.max_payload_size
      },
      "filter" => %{
        "supported" => true,
        "maxResults" => 200
      },
      "changePassword" => %{
        "supported" => true
      },
      "sort" => %{
        "supported" => true
      },
      "etag" => %{
        "supported" => true
      },
      "authenticationSchemes" => [
        %{
          "name" => "OAuth Bearer Token",
          "description" => "Authentication scheme using the OAuth Bearer Token Standard",
          "specUri" => "https://www.rfc-editor.org/info/rfc6750",
          "documentationUri" => "#{base_url}/help/oauth.html",
          "type" => "oauthbearertoken",
          "primary" => true
        },
        %{
          "name" => "HTTP Basic",
          "description" => "Authentication scheme using the HTTP Basic Standard",
          "specUri" => "https://www.rfc-editor.org/info/rfc2617",
          "documentationUri" => "#{base_url}/help/httpBasic.html",
          "type" => "httpbasic"
        }
      ]
    }

    json(conn, config)
  end

  defp get_bulk_config do
    %{
      supported: Application.get_env(:ex_scim, :bulk_supported, true),
      max_operations: Application.get_env(:ex_scim, :bulk_max_operations, 1000),
      max_payload_size: Application.get_env(:ex_scim, :bulk_max_payload_size, 1_048_576)
    }
  end
end
