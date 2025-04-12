defmodule Kaguyabot.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Kaguyabot.CommentPoller
    ]

    opts = [strategy: :one_for_one, name: Kaguyabot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
