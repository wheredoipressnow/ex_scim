defmodule Client.ScimTesting do
  @moduledoc """
  Context module for SCIM integration testing.

  Provides functions for running SCIM API tests, generating test data,
  and managing test execution lifecycle.
  """

  alias ExScimClient.Resources.Users
  alias ExScimClient.Me
  alias ExScimClient.Resources.Bulk
  alias ExScimClient.Resources.Schemas
  alias ExScimClient.Resources.ResourceTypes

  @test_definitions [
    %{id: :create_user, name: "Create User", icon: "📝", description: "Create a new user account"},
    %{id: :get_user, name: "Get User", icon: "🔍", description: "Fetch user details"},
    %{id: :update_user, name: "Update User", icon: "✏️", description: "Modify user information"},
    %{id: :patch_user, name: "Patch User", icon: "🔧", description: "Apply partial user updates"},
    %{id: :list_users, name: "List Users", icon: "📋", description: "Browse all users"},
    %{id: :delete_user, name: "Delete User", icon: "🗑️", description: "Remove the test user"},
    %{
      id: :me_operations,
      name: "User Profile",
      icon: "👤",
      description: "Check current user information"
    },
    %{
      id: :schema_operations,
      name: "Schema Info",
      icon: "📋",
      description: "Get data structure details"
    },
    %{
      id: :resource_types,
      name: "Resource Types",
      icon: "🏷️",
      description: "List available resource types"
    },
    %{
      id: :bulk_operations,
      name: "Bulk Operations",
      icon: "📦",
      description: "Process multiple operations at once"
    }
  ]

  @doc """
  Returns the list of available test definitions.
  """
  def test_definitions, do: @test_definitions

  @doc """
  Initializes test results map with all tests in pending state.
  """
  def init_test_results do
    Enum.reduce(@test_definitions, %{}, fn test, acc ->
      Map.put(acc, test.id, %{status: :pending, result: nil, error: nil})
    end)
  end

  @doc """
  Runs all SCIM tests in sequence.

  This function orchestrates the entire test suite, sending progress messages
  to the provided process ID.
  """
  def run_all_tests(pid, client) do
    send(pid, {:log_message, "🚀 Starting SCIM Integration Tests"})

    user_id =
      case run_single_test(pid, client, :create_user, nil) do
        {:ok, id} -> id
        _ -> nil
      end

    if user_id do
      send(pid, {:user_created, user_id})

      Enum.each([:get_user, :update_user, :patch_user], fn test ->
        run_single_test(pid, client, test, user_id)
      end)
    end

    Enum.each(
      [:list_users, :me_operations, :schema_operations, :resource_types, :bulk_operations],
      fn test ->
        run_single_test(pid, client, test, user_id)
      end
    )

    if user_id, do: run_single_test(pid, client, :delete_user, user_id)

    send(pid, {:tests_completed})
  end

  @doc """
  Runs a single test and reports progress to the provided process ID.
  """
  def run_single_test(pid, client, test_id, user_id) do
    send(pid, {:test_started, test_id})
    send(pid, {:log_message, "Running #{test_id}..."})

    # Validate client first
    case validate_client(client) do
      :ok ->
        result = execute_test_safely(test_id, client, user_id)
        handle_test_result(pid, test_id, result)

      {:error, reason} ->
        send(pid, {:test_failed, test_id, reason})
        send(pid, {:log_message, "❌ #{test_id} failed: #{reason}"})
        {:error, reason}
    end
  end

  defp validate_client(nil),
    do: {:error, "SCIM client not configured - please set BASE_URL and BEARER_TOKEN"}

  defp validate_client(_client), do: :ok

  defp execute_test_safely(test_id, client, user_id) do
    try do
      case test_id do
        :create_user -> test_create_user(client)
        :get_user -> test_get_user(client, user_id)
        :update_user -> test_update_user(client, user_id)
        :patch_user -> test_patch_user(client, user_id)
        :list_users -> test_list_users(client)
        :delete_user -> test_delete_user(client, user_id)
        :me_operations -> test_me_operations(client)
        :schema_operations -> test_schema_operations(client)
        :resource_types -> test_resource_type_operations(client)
        :bulk_operations -> test_bulk_operations(client)
      end
    rescue
      error -> {:error, "Connection failed: #{inspect(error)}"}
    catch
      :exit, reason -> {:error, "Connection terminated: #{inspect(reason)}"}
      error -> {:error, "Request failed: #{inspect(error)}"}
    end
  end

  defp handle_test_result(pid, test_id, result) do
    case result do
      {:ok, data} ->
        send(pid, {:test_completed, test_id, data})
        send(pid, {:log_message, "✅ #{test_id} completed successfully"})
        {:ok, data}

      {:error, reason} ->
        error_message = format_error(reason)
        send(pid, {:test_failed, test_id, error_message})
        send(pid, {:log_message, "❌ #{test_id} failed: #{error_message}"})
        {:error, error_message}

      other ->
        error_msg = "Unexpected response format: #{inspect(other)}"
        send(pid, {:test_failed, test_id, error_msg})
        send(pid, {:log_message, "❌ #{test_id} failed: #{error_msg}"})
        {:error, error_msg}
    end
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp test_create_user(client) do
    user_data = generate_random_user()

    case Users.create(client, user_data) do
      {:ok, %{"id" => user_id} = _response} -> {:ok, user_id}
      error -> error
    end
  end

  defp test_get_user(client, user_id) do
    Users.get(client, user_id)
  end

  defp test_update_user(client, user_id) do
    updated_data = generate_random_user_update()
    Users.update(client, user_id, updated_data)
  end

  defp test_patch_user(client, user_id) do
    patch_operations = [
      %{
        "op" => "replace",
        "path" => "title",
        "value" => "Senior #{generate_random_job_title()}"
      }
    ]

    Users.patch(client, user_id, patch_operations)
  end

  defp test_list_users(client) do
    Users.list(client)
  end

  defp test_delete_user(client, user_id) do
    Users.delete(client, user_id)
  end

  defp test_me_operations(client) do
    Me.get(client)
  end

  defp test_schema_operations(client) do
    Schemas.list(client)
  end

  defp test_resource_type_operations(client) do
    ResourceTypes.list(client)
  end

  defp test_bulk_operations(client) do
    user1_data = generate_random_user()
    user2_data = generate_random_user()

    bulk_operations = [
      %{
        "method" => "POST",
        "path" => "/Users",
        "bulkId" => "bulk_user_1",
        "data" => user1_data
      },
      %{
        "method" => "POST",
        "path" => "/Users",
        "bulkId" => "bulk_user_2",
        "data" => user2_data
      }
    ]

    bulk_request = %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:BulkRequest"],
      "Operations" => bulk_operations
    }

    Bulk.execute(client, bulk_request)
  end

  # Data generation functions

  defp generate_random_user do
    random_id = generate_random_string(8)
    first_name = Enum.random(["John", "Jane", "Alice", "Bob", "Charlie", "Diana", "Eve", "Frank"])

    last_name =
      Enum.random(["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis"])

    %{
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
      "userName" => "test_user_#{random_id}",
      "name" => %{
        "givenName" => first_name,
        "familyName" => last_name
      },
      "displayName" => "#{first_name} #{last_name}",
      "emails" => [
        %{
          "value" =>
            "#{String.downcase(first_name)}.#{String.downcase(last_name)}#{random_id}@example.com",
          "type" => "work",
          "primary" => true
        }
      ],
      "active" => true,
      "title" => generate_random_job_title()
    }
  end

  defp generate_random_user_update do
    random_id = generate_random_string(6)
    first_name = Enum.random(["Updated", "Modified", "Changed", "New"])
    last_name = Enum.random(["User", "Person", "Individual", "Account"])

    %{
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
      "displayName" => "#{first_name} #{last_name} #{random_id}",
      "title" => "Updated #{generate_random_job_title()}"
    }
  end

  defp generate_random_job_title do
    titles = [
      "Software Engineer",
      "Product Manager",
      "Data Analyst",
      "Designer",
      "Developer",
      "Consultant",
      "Architect",
      "Manager"
    ]

    Enum.random(titles)
  end

  defp generate_random_string(length) do
    chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    chars_list = String.graphemes(chars)

    1..length
    |> Enum.map(fn _ -> Enum.random(chars_list) end)
    |> Enum.join("")
  end
end
