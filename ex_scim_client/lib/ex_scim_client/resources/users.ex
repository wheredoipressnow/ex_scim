defmodule ExScimClient.Resources.Users do
  alias ExScimClient.Client
  alias ExScimClient.Request

  def create(%Client{} = client, user_data) when is_map(user_data) do
    Request.new(client)
    |> Request.path("/Users")
    |> Request.method(:post)
    |> Request.body(user_data)
    |> Request.run()
  end

  def get(%Client{} = client, id, opts \\ []) when is_binary(id) do
    attributes = Keyword.get(opts, :attributes)
    excluded_attributes = Keyword.get(opts, :excluded_attributes)

    Request.new(client)
    |> Request.path("/Users/#{id}")
    |> Request.method(:get)
    |> Request.attributes(attributes)
    |> Request.excluded_attributes(excluded_attributes)
    |> Request.run()
  end

  def list(%Client{} = client, opts \\ []) do
    filter = Keyword.get(opts, :filter)
    sorting = Keyword.get(opts, :sorting)
    pagination = Keyword.get(opts, :pagination)
    attributes = Keyword.get(opts, :attributes)
    excluded_attributes = Keyword.get(opts, :excluded_attributes)

    Request.new(client)
    |> Request.path("/Users")
    |> Request.method(:get)
    |> Request.filter(filter)
    |> Request.sort_by(sorting)
    |> Request.paginate(pagination)
    |> Request.attributes(attributes)
    |> Request.excluded_attributes(excluded_attributes)
    |> Request.run()
  end

  def update(%Client{} = client, id, user_data) when is_binary(id) and is_map(user_data) do
    Request.new(client)
    |> Request.path("/Users/#{id}")
    |> Request.method(:put)
    |> Request.body(user_data)
    |> Request.run()
  end

  def patch(%Client{} = client, id, operations)
      when is_binary(id) and is_list(operations) do
    patch_body = %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
      "Operations" => operations
    }

    Request.new(client)
    |> Request.path("/Users/#{id}")
    |> Request.method(:patch)
    |> Request.body(patch_body)
    |> Request.run()
  end

  def delete(%Client{} = client, id) when is_binary(id) do
    Request.new(client)
    |> Request.path("/Users/#{id}")
    |> Request.method(:delete)
    |> Request.run()
  end
end
