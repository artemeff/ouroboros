Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)

Logger.configure(level: :warn)

# Load up the repository, start it, and run migrations
_ = Ecto.Adapters.Postgres.storage_down(Snake.Repo.config())
:ok = Ecto.Adapters.Postgres.storage_up(Snake.Repo.config())
{:ok, _} = Snake.Repo.start_link()
:ok = Ecto.Migrator.up(Snake.Repo, 0, Snake.Migration, log: false)

Ecto.Adapters.SQL.Sandbox.mode(Snake.Repo, :manual)

ExUnit.start(capture_log: true)
