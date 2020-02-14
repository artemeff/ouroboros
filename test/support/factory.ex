defmodule Snake.Factory do
  use ExMachina.Ecto, repo: Snake.Repo

  alias Snake.{Customer, Address, Payment}

  def customer_factory do
    %Customer{
      name: "Bob",
      active: true
    }
  end

  def address_factory do
    %Address{
      city: "City name",
      customer: build(:customer)
    }
  end

  def payment_factory do
    %Payment{
      description: "Skittles",
      charged_at: DateTime.utc_now(),
      # +10 so it doesn't mess with low amounts we want to order on.
      amount: :rand.uniform(100) + 10,
      status: "success",
      customer: build(:customer)
    }
  end
end
