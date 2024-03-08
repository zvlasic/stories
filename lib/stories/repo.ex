defmodule Stories.Repo do
  use Ecto.Repo,
    otp_app: :stories,
    adapter: Ecto.Adapters.Postgres
end
