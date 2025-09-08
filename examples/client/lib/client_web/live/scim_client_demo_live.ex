defmodule ClientWeb.ScimClientDemoLive do
  use ClientWeb, :live_view

  alias ExScimClient.Client, as: ScimClient
  alias Client.ScimTesting

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        base_url: "",
        bearer_token: "",
        client: nil,
        test_results: ScimTesting.init_test_results(),
        current_test: nil,
        running: false,
        test_task_pid: nil,
        progress: 0,
        logs: [],
        created_user_id: nil
      )

    send(self(), :load_saved_config)

    {:ok, socket}
  end

  def handle_event(
        "update_config",
        %{"base_url" => base_url, "bearer_token" => bearer_token},
        socket
      ) do
    {normalized_base_url, client} = create_scim_client(base_url, bearer_token)

    socket =
      assign(socket,
        base_url: normalized_base_url,
        bearer_token: bearer_token,
        client: client
      )

    {:noreply, socket}
  end

  def handle_event("start_tests", _params, socket) do
    case validate_configuration(socket) do
      :ok ->
        send(self(), :run_tests)

        socket =
          assign(socket,
            running: true,
            progress: 0,
            test_results: ScimTesting.init_test_results(),
            logs: [],
            created_user_id: nil
          )

        {:noreply, socket}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("stop_tests", _params, socket) do
    if socket.assigns.test_task_pid do
      Process.exit(socket.assigns.test_task_pid, :kill)
    end

    test_results =
      socket.assigns.test_results
      |> Enum.map(fn {test_id, result} ->
        if result.status == :running do
          {test_id, %{status: :pending, result: nil, error: nil}}
        else
          {test_id, result}
        end
      end)
      |> Map.new()

    socket =
      assign(socket,
        running: false,
        current_test: nil,
        test_task_pid: nil,
        test_results: test_results,
        progress: 0
      )

    {:noreply, put_flash(socket, :info, "Tests stopped")}
  end

  def handle_event("retry_test", %{"test_id" => test_id}, socket) do
    test_atom = String.to_existing_atom(test_id)
    send(self(), {:retry_test, test_atom})

    socket =
      update(socket, :test_results, fn results ->
        Map.put(results, test_atom, %{status: :running, result: nil, error: nil})
      end)

    {:noreply, socket}
  end

  def handle_event(
        "config_loaded",
        %{"base_url" => base_url, "bearer_token" => bearer_token},
        socket
      ) do
    {normalized_base_url, client} = create_scim_client(base_url, bearer_token)

    socket =
      assign(socket,
        base_url: normalized_base_url,
        bearer_token: bearer_token,
        client: client
      )

    {:noreply, socket}
  end

  def handle_info(:run_tests, socket) do
    live_view_pid = self()

    {:ok, task_pid} =
      Task.start(fn -> ScimTesting.run_all_tests(live_view_pid, socket.assigns.client) end)

    socket = assign(socket, test_task_pid: task_pid)
    {:noreply, socket}
  end

  def handle_info({:retry_test, test_id}, socket) do
    live_view_pid = self()

    Task.start(fn ->
      ScimTesting.run_single_test(
        live_view_pid,
        socket.assigns.client,
        test_id,
        socket.assigns.created_user_id
      )
    end)

    {:noreply, socket}
  end

  def handle_info({:test_started, test_id}, socket) do
    socket = assign(socket, current_test: test_id)

    socket =
      update(socket, :test_results, fn results ->
        Map.put(results, test_id, %{status: :running, result: nil, error: nil})
      end)

    {:noreply, socket}
  end

  def handle_info({:test_completed, test_id, result}, socket) do
    socket =
      update(socket, :test_results, fn results ->
        Map.put(results, test_id, %{status: :success, result: result, error: nil})
      end)

    socket =
      update(socket, :progress, fn progress ->
        min(progress + 10, 100)
      end)

    {:noreply, socket}
  end

  def handle_info({:test_failed, test_id, error}, socket) do
    socket =
      update(socket, :test_results, fn results ->
        Map.put(results, test_id, %{status: :error, result: nil, error: error})
      end)

    socket =
      update(socket, :progress, fn progress ->
        min(progress + 10, 100)
      end)

    {:noreply, socket}
  end

  def handle_info({:user_created, user_id}, socket) do
    {:noreply, assign(socket, created_user_id: user_id)}
  end

  def handle_info({:log_message, message}, socket) do
    socket =
      update(socket, :logs, fn logs ->
        [%{timestamp: DateTime.utc_now(), message: message} | logs]
      end)

    {:noreply, socket}
  end

  def handle_info({:tests_completed}, socket) do
    socket =
      assign(socket,
        running: false,
        current_test: nil,
        progress: 100,
        test_task_pid: nil
      )

    {:noreply, socket}
  end

  def handle_info(:load_saved_config, socket) do
    {:noreply, push_event(socket, "load_saved_config", %{})}
  end

  def test_definitions, do: ScimTesting.test_definitions()

  defp create_scim_client("", _bearer_token), do: {"", nil}
  defp create_scim_client(_base_url, ""), do: {"", nil}

  defp create_scim_client(base_url, bearer_token) do
    normalized_base_url = normalize_base_url(base_url)
    client = ScimClient.new(normalized_base_url, bearer_token)
    {normalized_base_url, client}
  end

  defp normalize_base_url(base_url) do
    base_url = String.trim_trailing(base_url, "/")

    if String.ends_with?(base_url, "/scim/v2") do
      base_url
    else
      base_url <> "/scim/v2"
    end
  end

  defp validate_configuration(socket) do
    cond do
      socket.assigns.base_url == "" ->
        {:error, "Please configure a valid BASE_URL (e.g., https://your-scim-server.com)"}

      socket.assigns.bearer_token == "" ->
        {:error, "Please configure a valid BEARER_TOKEN"}

      socket.assigns.client == nil ->
        {:error, "SCIM client configuration failed"}

      true ->
        :ok
    end
  end
end
