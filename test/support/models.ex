defmodule Ouroboros.Address do
  use Ecto.Schema

  @primary_key {:city, :string, autogenerate: false}

  schema "addresses" do
    belongs_to(:customer, Ouroboros.Customer)
  end
end

defmodule Ouroboros.Customer do
  use Ecto.Schema

  import Ecto.Query

  schema "customers" do
    field(:name, :string)
    field(:active, :boolean)

    has_many(:payments, Ouroboros.Payment)
    has_one(:address, Ouroboros.Address)

    timestamps(type: :utc_datetime_usec)
  end

  def active(query) do
    query |> where([c], c.active == true)
  end
end

defmodule Ouroboros.Payment do
  use Ecto.Schema

  import Ecto.Query

  schema "payments" do
    field(:amount, :integer)
    field(:charged_at, :utc_datetime)
    field(:description, :string)
    field(:status, :string)

    belongs_to(:customer, Ouroboros.Customer)

    timestamps(type: :utc_datetime_usec)
  end

  def successful(query) do
    query |> where([p], p.status == "success")
  end

  def failed(query) do
    query |> where([p], p.status == "failed")
  end
end
