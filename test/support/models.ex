defmodule Snake.Address do
  use Ecto.Schema

  @primary_key {:city, :string, autogenerate: false}

  schema "addresses" do
    belongs_to(:customer, Snake.Customer)
  end
end

defmodule Snake.Customer do
  use Ecto.Schema

  import Ecto.Query

  schema "customers" do
    field(:name, :string)
    field(:active, :boolean)

    has_many(:payments, Snake.Payment)
    has_one(:address, Snake.Address)

    timestamps()
  end

  def active(query) do
    query |> where([c], c.active == true)
  end
end

defmodule Snake.Payment do
  use Ecto.Schema

  import Ecto.Query

  schema "payments" do
    field(:amount, :integer)
    field(:charged_at, :utc_datetime)
    field(:description, :string)
    field(:status, :string)

    belongs_to(:customer, Snake.Customer)

    timestamps()
  end

  def successful(query) do
    query |> where([p], p.status == "success")
  end

  def failed(query) do
    query |> where([p], p.status == "failed")
  end
end
