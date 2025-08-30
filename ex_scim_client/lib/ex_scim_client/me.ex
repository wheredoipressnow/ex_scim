defmodule ExScimClient.Me do
  alias ExScimClient.Client
  alias ExScimClient.Request

  def get(%Client{} = client, opts \\ []) do
    attributes = Keyword.get(opts, :attributes)
    excluded_attributes = Keyword.get(opts, :excluded_attributes)

    Request.new(client)
    |> Request.path("/Me")
    |> Request.method(:get)
    |> Request.attributes(attributes)
    |> Request.excluded_attributes(excluded_attributes)
    |> Request.run()
  end

  def update(%Client{} = client, user_data) when is_map(user_data) do
    Request.new(client)
    |> Request.path("/Me")
    |> Request.method(:put)
    |> Request.body(user_data)
    |> Request.run()
  end

  def patch(%Client{} = client, operations) when is_list(operations) do
    patch_body = %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
      "Operations" => operations
    }

    Request.new(client)
    |> Request.path("/Me")
    |> Request.method(:patch)
    |> Request.body(patch_body)
    |> Request.run()
  end
end
