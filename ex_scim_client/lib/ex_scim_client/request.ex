defmodule ExScimClient.Request do
  @moduledoc """
  Low-level SCIM request builder DSL.
  Composes the requests that later executed by Req.
  """
  alias Req
  alias ExScimClient.Client
  alias ExScimClient.Filter
  alias ExScimClient.Sorting
  alias ExScimClient.Pagination

  @type t :: keyword()

  def new(%Client{base_url: base, bearer: bearer, default_headers: dh}) do
    [
      base_url: base,
      headers: [{"authorization", "Bearer #{bearer}"} | dh]
    ]
  end

  def bearer(req, token) do
    headers = Keyword.get(req, :headers, [])
    Keyword.put(req, :headers, [{"authorization", "Bearer #{token}"} | headers])
  end

  def basic(req, username, password) do
    credentials = Base.encode64("#{username}:#{password}")
    headers = Keyword.get(req, :headers, [])
    Keyword.put(req, :headers, [{"authorization", "Basic #{credentials}"} | headers])
  end

  def path(req, endpoint) do
    base_url = Keyword.get(req, :base_url)

    if is_nil(base_url) do
      raise ArgumentError, "base_url cannot be nil"
    end

    # Ensure base_url ends with / and endpoint starts without /
    normalized_base = if String.ends_with?(base_url, "/"), do: base_url, else: base_url <> "/"
    normalized_endpoint = String.trim_leading(endpoint, "/")

    full_url = normalized_base <> normalized_endpoint
    Keyword.put(req, :url, full_url)
  end

  def method(req, verb) do
    Keyword.put(req, :method, verb)
  end

  def body(req, json) do
    Keyword.put(req, :json, json)
  end

  def filter(req, %Filter{} = filter_struct) do
    filter(req, Filter.build(filter_struct))
  end

  def filter(req, filter_string) when is_binary(filter_string) do
    scim_params = Keyword.get(req, :scim_params, %{})
    updated_params = Map.put(scim_params, :filter, filter_string)
    Keyword.put(req, :scim_params, updated_params)
  end

  def filter(req, _), do: req

  def sort_by(req, %Sorting{} = sorting_struct) do
    updated_params =
      req
      |> Keyword.get(:scim_params, %{})
      |> Map.merge(%{sort_by: sorting_struct.by, sort_order: sorting_struct.order})

    Keyword.put(req, :scim_params, updated_params)
  end

  def sort_by(req, _), do: req

  def paginate(req, %Pagination{} = pagination_struct) do
    updated_params =
      req
      |> Keyword.get(:scim_params, %{})
      |> Map.merge(%{start_index: pagination_struct.start_index, count: pagination_struct.count})

    Keyword.put(req, :scim_params, updated_params)
  end

  def paginate(req, _), do: req

  def attributes(req, attribute_list) when is_list(attribute_list) do
    scim_params = Keyword.get(req, :scim_params, %{})
    updated_params = Map.put(scim_params, :attributes, attribute_list)
    Keyword.put(req, :scim_params, updated_params)
  end

  def attributes(req, _), do: req

  def excluded_attributes(req, attribute_list)
      when is_list(attribute_list) do
    scim_params = Keyword.get(req, :scim_params, %{})
    updated_params = Map.put(scim_params, :excluded_attributes, attribute_list)
    Keyword.put(req, :scim_params, updated_params)
  end

  def excluded_attributes(req, _), do: req

  defp build_query_parameters(req) do
    case Keyword.get(req, :scim_params) do
      nil ->
        req

      scim_params when map_size(scim_params) == 0 ->
        req

      scim_params ->
        current_url = Keyword.get(req, :url)
        if is_nil(current_url), do: raise(ArgumentError, "url cannot be nil")

        query_map = build_scim_query_map(scim_params)
        updated_url = merge_query_parameter(current_url, query_map)

        req
        |> Keyword.put(:url, updated_url)
        # Clean up after building
        |> Keyword.delete(:scim_params)
    end
  end

  defp build_scim_query_map(scim_params) do
    scim_params
    |> Enum.reduce(%{}, fn
      {:filter, %Filter{} = filter}, acc ->
        Map.put(acc, "filter", Filter.build(filter))

      {:filter, filter_string}, acc when is_binary(filter_string) ->
        Map.put(acc, "filter", filter_string)

      {:sort_by, attribute}, acc ->
        Map.put(acc, "sortBy", attribute)

      # Default, don't add
      {:sort_order, :asc}, acc ->
        acc

      {:sort_order, :desc}, acc ->
        Map.put(acc, "sortOrder", "descending")

      {:start_index, index}, acc ->
        Map.put(acc, "startIndex", to_string(index))

      {:count, count}, acc ->
        Map.put(acc, "count", to_string(count))

      {:attributes, attrs}, acc when is_list(attrs) ->
        Map.put(acc, "attributes", Enum.join(attrs, ","))

      {:excluded_attributes, attrs}, acc when is_list(attrs) ->
        Map.put(acc, "excludedAttributes", Enum.join(attrs, ","))

      # Ignore unknown parameters
      {_key, _value}, acc ->
        acc
    end)
  end

  defp merge_query_parameter(current_url, params) do
    uri = URI.parse(current_url)

    # Merge new params with existing query params
    existing_params = URI.decode_query(uri.query || "")
    merged_params = Map.merge(existing_params, params)

    %{uri | query: URI.encode_query(merged_params)}
    |> URI.to_string()
  end

  def run(req) do
    req
    |> build_query_parameters()
    |> do_run()
  end

  defp do_run(req) do
    with request <- Req.new(req),
         {:ok, response} <- Req.request(request) do
      {:ok, response.body}
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, error}
    end
  end
end
