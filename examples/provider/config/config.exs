# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :provider,
  ecto_repos: [Provider.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :provider, ProviderWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ProviderWeb.ErrorHTML, json: ProviderWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Provider.PubSub,
  live_view: [signing_salt: "GhknlGDr"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :provider, Provider.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  provider: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  provider: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ex_scim,
  base_url: "http://host.docker.internal:4000",
  auth_provider_adapter: Provider.Scim.FakeAuthProvider,
  user_resource_mapper: Provider.Scim.UserMapper,
  group_resource_mapper: Provider.Scim.GroupMapper,
  scim_validator: ExScim.Schema.Validator.DefaultValidator,
  scim_schema_repository: ExScim.Schema.Repository.DefaultRepository,
  storage_strategy: ExScimEcto.StorageAdapter,
  storage_repo: Provider.Repo,
  user_model: Provider.Accounts.User,
  group_model: Provider.Accounts.Group,
  bulk_supported: true,
  bulk_max_operations: 1000,
  bulk_max_payload_size: 1_048_576

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
