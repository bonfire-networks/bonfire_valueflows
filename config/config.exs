use Mix.Config

#### Email configuration

# You will almost certainly want to change at least some of these

# include Phoenix web server boilerplate
# import_config "bonfire_web_phoenix.exs"

# include all used Bonfire extensions
import_config "bonfire_valueflows.exs"


#### Basic configuration

# You probably won't want to touch these. You might override some in
# other config files.



config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :mime, :types, %{
  "application/activity+json" => ["activity+json"]
}

# import_config "#{Mix.env()}.exs"
