defmodule Snake.Repo do
  use Ecto.Repo, otp_app: :snake, adapter: Ecto.Adapters.Postgres
  use Snake

  def init(_type, config) do
    {:ok, Keyword.merge(config, [
      database: "snake_db",
      pool: Ecto.Adapters.SQL.Sandbox
    ])}
  end
end
