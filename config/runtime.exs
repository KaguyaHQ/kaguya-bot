import Config
import Dotenvy

# Load .env file
source!([".env", System.get_env()])

config :kaguyabot,
  reddit: [
    client_id: env!("REDDIT_CLIENT_ID", :string!),
    client_secret: env!("REDDIT_SECRET", :string!),
    username: env!("REDDIT_USERNAME", :string!),
    password: env!("REDDIT_PASSWORD", :string!),
    user_agent: env!("REDDIT_USER_AGENT", :string!)
  ]

# Repo config using DATABASE_URL
if config_env() == :prod or config_env() == :dev do
  config :kaguyabot, Kaguyabot.Repo,
    url: env!("DATABASE_URL", :string!),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")
end
