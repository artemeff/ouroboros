defmodule Snake.Page do
  @moduledoc """
  Defines a page.

  ## Fields

  * `entries` - a list entries contained in this page.
  * `metadata` - metadata attached to this page.

  """

  @type t :: %__MODULE__{
    entries: [any()] | [],
    metadata: Paginator.Page.Metadata.t()
  }

  defstruct [:metadata, :entries]

  defimpl Enumerable do
    def count(%Snake.Page{entries: entries}) do
      {:ok, length(entries)}
    end

    def member?(_page, _value) do
      {:error, __MODULE__}
    end

    def reduce(%Snake.Page{entries: entries}, acc, fun) do
      Enumerable.reduce(entries, acc, fun)
    end

    def slice(_page) do
      {:error, __MODULE__}
    end
  end
end
