defmodule Ouroboros.Repo do
  use Ecto.Repo, otp_app: :ouroboros, adapter: Ecto.Adapters.Postgres
  use Ouroboros

  def init(_type, config) do
    {:ok, Keyword.merge(config, [
      username: "postgres",
      password: "postgres",
      database: "ouroboros_db",
      hostname: "localhost",
      pool: Ecto.Adapters.SQL.Sandbox
    ])}
  end
end
