defmodule ExScimClient.Resources.Bulk do
  alias ExScimClient.Client
  alias ExScimClient.Request

  def execute(%Client{} = client, operations) do
    Request.new(client)
    |> Request.path("/Bulk")
    |> Request.method(:post)
    |> Request.body(operations)
    |> Request.run()
  end
end
