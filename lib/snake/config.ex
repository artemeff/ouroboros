defmodule Snake.Config do
  @moduledoc false

  @type t :: %__MODULE__{}

  defstruct [
    :after,
    :after_values,
    :before,
    :before_values,
    :fields,
    :value_fun,
    :limit,
    :limit_max
  ]

  @limit_default 50
  @limit_min 1
  @limit_max 100

  def new(%Ecto.Query{from: %Ecto.Query.FromExpr{source: {_, module}}}, opts \\ []) do
    cursor_after = Keyword.get(opts, :after)
    cursor_before = Keyword.get(opts, :before)

    fields = Keyword.get(opts, :fields, [])
    fields_types = Enum.map(fields, fn({field, _ordering}) -> Snake.type_fun_default(struct(module), field) end)

    %__MODULE__{
      after: cursor_after,
      after_values: Snake.Cursor.decode(fields_types, cursor_after),
      before: cursor_before,
      before_values: Snake.Cursor.decode(fields_types, cursor_before),
      fields: fields,
      value_fun: Keyword.get(opts, :value_fun, &Snake.value_fun_default/2),
      limit: limit(opts)
    }
  end

  defp limit(opts) do
    limit = Keyword.get(opts, :limit, @limit_default)
    limit_max = Keyword.get(opts, :limit_max, @limit_max)

    limit |> max(@limit_min) |> min(limit_max)
  end
end
