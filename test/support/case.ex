defmodule Snake.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Ecto
      import Ecto.Query
      import Snake.Factory

      alias Snake.{Repo, Page, Page.Metadata}
      alias Snake.{Customer, Address, Payment}
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Snake.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Snake.Repo, {:shared, self()})
    end

    :ok
  end
end
