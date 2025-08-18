defmodule Provider.Scim.GroupMapper do
  @moduledoc """
  Data transformation between SCIM format and Provider.Accounts.Group domain struct.
  """

  @behaviour ExScim.Groups.Mapper.Adapter

  alias Provider.Accounts.Group
  alias ExScim.Config

  @doc """
  Converts SCIM group data to a domain Group struct.
  """
  def from_scim(scim_data) do
    %Group{
      display_name: scim_data["displayName"],
      description: scim_data["description"] || scim_data["displayName"],
      external_id: scim_data["externalId"] || scim_data["displayName"],
      active: Map.get(scim_data, "active", true),
      meta_created: parse_datetime(get_in(scim_data, ["meta", "created"])),
      meta_last_modified: parse_datetime(get_in(scim_data, ["meta", "lastModified"]))
    }
  end

  @doc """
  Converts a domain Group struct to SCIM format.
  """
  def to_scim(%Group{} = group, opts \\ []) do
    location = Keyword.get(opts, :location)

    %{
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"],
      "id" => group.id,
      "externalId" => group.external_id,
      "displayName" => group.display_name,
      "description" => group.description,
      "active" => group.active,
      "members" => format_members(group),
      "meta" => format_meta(group, location)
    }
  end

  # Private helper functions

  defp format_members(%Group{users: users}) when is_list(users) do
    Enum.map(users, fn user ->
      %{
        "value" => user.id,
        "display" => user.display_name || user.user_name,
        "$ref" => generate_user_location(user.id),
        "type" => "User"
      }
    end)
  end

  defp format_members(_), do: []

  defp format_meta(%Group{} = group, location) do
    location = location || generate_group_location(group.id)

    %{
      "created" => format_datetime(group.meta_created),
      "lastModified" => format_datetime(group.meta_last_modified),
      "resourceType" => "Group",
      "location" => location,
      "etag" => generate_etag(group.meta_last_modified)
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

  defp generate_group_location(group_id) when is_binary(group_id) do
    Config.resource_url("Groups", group_id)
  end

  defp generate_group_location(_), do: nil

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
