defmodule Stories.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      StoriesWeb.Telemetry,
      Stories.Repo,
      {Phoenix.PubSub, name: Stories.PubSub},
      {Finch, name: Stories.Finch},
      StoriesWeb.Endpoint,
      {Task.Supervisor, name: Stories.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: Stories.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    StoriesWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
