defmodule Provider.Scim.UserMapper do
  @moduledoc """
  Data transformation between SCIM format and Provider.Accounts.User domain struct.
  """

  @behaviour ExScim.Users.Mapper.Adapter

  alias Provider.Accounts.User
  alias ExScim.Config

  @doc """
  Converts SCIM user data to a domain User struct.
  """
  def from_scim(scim_data) do
    %User{
      user_name: scim_data["userName"],
      given_name: get_in(scim_data, ["name", "givenName"]),
      family_name: get_in(scim_data, ["name", "familyName"]),
      display_name: scim_data["displayName"],
      email: get_primary_email(scim_data["emails"]),
      active: Map.get(scim_data, "active", true),
      external_id: scim_data["externalId"] || scim_data["userName"],
      meta_created: parse_datetime(get_in(scim_data, ["meta", "created"])),
      meta_last_modified: parse_datetime(get_in(scim_data, ["meta", "lastModified"]))
    }
  end

  @doc """
  Converts a domain User struct to SCIM format.
  """
  def to_scim(%User{} = user, opts \\ []) do
    location = Keyword.get(opts, :location)

    %{
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
      "id" => user.id,
      "externalId" => user.external_id,
      "userName" => user.user_name,
      "displayName" => user.display_name,
      "active" => user.active,
      "emails" => format_emails(user.email),
      "name" => format_name(user),
      "meta" => format_meta(user, location)
    }
  end

  # Private helper functions

  defp get_primary_email(emails) when is_list(emails) do
    case Enum.find(emails, &Map.get(&1, "primary", false)) || List.first(emails) do
      %{"value" => email} -> email
      _ -> nil
    end
  end

  defp get_primary_email(_), do: nil

  defp format_emails(nil), do: []

  defp format_emails(email) when is_binary(email) do
    [%{"value" => email, "primary" => true}]
  end

  defp format_name(%User{given_name: given_name, family_name: family_name}) do
    formatted =
      case {given_name, family_name} do
        {nil, nil} -> nil
        {given, nil} -> given
        {nil, family} -> family
        {given, family} -> "#{given} #{family}"
      end

    %{
      "givenName" => given_name,
      "familyName" => family_name,
      "formatted" => formatted
    }
  end

  defp format_meta(%User{} = user, location) do
    location = location || generate_user_location(user.id)

    %{
      "created" => format_datetime(user.meta_created),
      "lastModified" => format_datetime(user.meta_last_modified),
      "resourceType" => "User",
      "location" => location,
      "etag" => generate_etag(user.meta_last_modified)
    }
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_datetime(binary) when is_binary(binary) do
    case DateTime.from_iso8601(binary) do
      {:ok, dt, _offset} -> dt
      {:error, _} -> nil
    end
  end

  defp format_datetime(nil), do: nil
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(binary) when is_binary(binary), do: binary

  defp generate_user_location(user_id) when is_binary(user_id) do
    Config.resource_url("Users", user_id)
  end

  defp generate_user_location(_), do: nil

  defp generate_etag(%DateTime{} = dt) do
    dt
    |> DateTime.to_iso8601()
    |> then(&:crypto.hash(:md5, &1))
    |> Base.encode16(case: :lower)
    |> then(&"\"#{&1}\"")
  end

  defp generate_etag(_), do: nil
end
