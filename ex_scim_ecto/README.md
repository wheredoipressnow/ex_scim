# ExScimEcto

Ecto storage adapter for ExScim.

## Configuration

```elixir
config :ex_scim,
  storage_strategy: ExScimEcto.StorageAdapter,
  storage_repo: MyApp.Repo,
  storage_schema: MyApp.Accounts.User
```


