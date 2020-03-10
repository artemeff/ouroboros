defmodule Ouroboros.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Ecto
      import Ecto.Query
      import Ouroboros.Factory

      alias Ouroboros.{Repo, Page, Page.Metadata}
      alias Ouroboros.{Customer, Address, Payment}
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Ouroboros.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Ouroboros.Repo, {:shared, self()})
    end

    :ok
  end
end
