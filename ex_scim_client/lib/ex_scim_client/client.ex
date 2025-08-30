defmodule ExScimClient.Client do
  defstruct [
    :base_url,
    :bearer,
    default_headers: [
      {"content-type", "application/scim+json"},
      {"accept", "application/scim+json"}
    ]
  ]

  def new(base_url, bearer), do: %__MODULE__{base_url: base_url, bearer: bearer}
end
