defmodule ExScimClient.Resources.Schemas do
  alias ExScimClient.Client
  alias ExScimClient.Request

  def list(%Client{} = client, opts \\ []) do
    filter = Keyword.get(opts, :filter)
    sorting = Keyword.get(opts, :sorting)
    pagination = Keyword.get(opts, :pagination)
    attributes = Keyword.get(opts, :attributes)
    excluded_attributes = Keyword.get(opts, :excluded_attributes)

    Request.new(client)
    |> Request.path("/Schemas")
    |> Request.method(:get)
    |> Request.filter(filter)
    |> Request.sort_by(sorting)
    |> Request.paginate(pagination)
    |> Request.attributes(attributes)
    |> Request.excluded_attributes(excluded_attributes)
    |> Request.run()
  end

  def get(%Client{} = client, schema_id, opts \\ []) when is_binary(schema_id) do
    # URL encode the schema ID since it contains special characters
    encoded_id = URI.encode(schema_id, &URI.char_unreserved?/1)

    attributes = Keyword.get(opts, :attributes)
    excluded_attributes = Keyword.get(opts, :excluded_attributes)

    Request.new(client)
    |> Request.path("/Schemas/#{encoded_id}")
    |> Request.method(:get)
    |> Request.attributes(attributes)
    |> Request.excluded_attributes(excluded_attributes)
    |> Request.run()
  end

  def user_schema(%Client{} = client, opts \\ []) do
    get(client, "urn:ietf:params:scim:schemas:core:2.0:User", opts)
  end

  def group_schema(%Client{} = client, opts \\ []) do
    get(client, "urn:ietf:params:scim:schemas:core:2.0:Group", opts)
  end

  def enterprise_user_schema(%Client{} = client, opts \\ []) do
    get(client, "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User", opts)
  end
end
