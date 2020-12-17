use Mix.Config

config :bonfire_valueflows,
  otp_app: :your_app_name,
  web_module: Bonfire.Web,
  repo_module: Bonfire.Repo,
  user_schema: Bonfire.Data.Identity.User,
  org_schema: Bonfire.Data.Identity.User,
  valid_agent_schemas: [Bonfire.Data.Identity.User],
  all_types: []
