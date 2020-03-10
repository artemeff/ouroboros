Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)

Logger.configure(level: :warn)

# Load up the repository, start it, and run migrations
_ = Ecto.Adapters.Postgres.storage_down(Ouroboros.Repo.config())
:ok = Ecto.Adapters.Postgres.storage_up(Ouroboros.Repo.config())
{:ok, _} = Ouroboros.Repo.start_link()
:ok = Ecto.Migrator.up(Ouroboros.Repo, 0, Ouroboros.Migration, log: false)

Ecto.Adapters.SQL.Sandbox.mode(Ouroboros.Repo, :manual)

ExUnit.start(capture_log: true)
