defmodule Kaguyabot.Repo do
  use Ecto.Repo,
    otp_app: :kaguyabot,
    adapter: Ecto.Adapters.Postgres
end
