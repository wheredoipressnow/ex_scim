defmodule Provider.Scim.FakeAuthProvider do
  @behaviour ExScim.Auth.AuthProvider.Adapter
  alias ExScim.Auth.Principal

  @fake_tokens %{
    "valid_bearer_token_123" => %{
      id: "scim_client_1",
      type: :client,
      scopes: ["scim:read", "scim:write"],
      expires_at: ~U[2025-12-31 23:59:59Z],
      active: true
    },
    "valid_user_token" => %{
      id: "263675ec-fb54-4229-add0-815d10532625",
      type: :user,
      scopes: [
        "scim:me:read",
        "scim:me:create",
        "scim:me:update",
        "scim:me:delete",
        "scim:read",
        "scim:write"
      ],
      expires_at: ~U[2025-12-31 23:59:59Z],
      active: true
    },
    "expired_token_456" => %{
      id: "scim_client_2",
      type: :client,
      scopes: ["scim:read"],
      expires_at: ~U[2024-01-01 00:00:00Z],
      active: false
    }
  }

  @fake_credentials %{
    {"scim_user", "scim_password123"} => %{
      id: "scim_client_basic",
      type: :user,
      scopes: ["scim:read", "scim:write"],
      display_name: "SCIM Basic Auth Client"
    },
    {"readonly_user", "readonly_pass"} => %{
      id: "scim_client_readonly",
      type: :user,
      scopes: ["scim:read"],
      display_name: "SCIM Read-Only Client"
    },
    {"scim", "scim"} => %{
      id: "scim_compliance_test",
      type: :user,
      scopes: ["scim:read", "scim:write"],
      display_name: "SCIM Compliance Test Client"
    }
  }

  @impl true
  def validate_bearer(token) do
    case Map.get(@fake_tokens, token) do
      %{active: true, expires_at: exp} = data ->
        if DateTime.compare(DateTime.utc_now(), exp) == :lt do
          {:ok, struct(Principal, Map.put(data, :metadata, %{}))}
        else
          {:error, :expired_token}
        end

      %{active: false} ->
        {:error, :inactive_token}

      nil ->
        {:error, :token_not_found}
    end
  end

  @impl true
  def validate_basic(username, password) do
    case Map.get(@fake_credentials, {username, password}) do
      nil ->
        {:error, :invalid_credentials}

      data ->
        {:ok, struct(Principal, Map.put(data, :username, username) |> Map.put(:metadata, %{}))}
    end
  end
end
