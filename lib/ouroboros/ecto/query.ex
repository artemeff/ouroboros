defmodule Ouroboros.Ecto.Query do
  @moduledoc false

  import Ecto.Query

  alias Ouroboros.Config

  def paginate(query, config \\ [])

  def paginate(query, %Config{} = config) do
    query
    |> maybe_where(config)
    |> limit(^query_limit(config))
  end

  def paginate(query, opts) do
    paginate(query, Config.new(query, opts))
  end

  def count(query) do
    query
    |> exclude(:preload)
    |> exclude(:order_by)
    |> aggregate()
  end

  defp aggregate(%{distinct: %{expr: [_ | _]}} = query) do
    query
    |> exclude(:select)
    |> count()
  end

  defp aggregate(
         %{
           group_bys: [
             %Ecto.Query.QueryExpr{
               expr: [
                 {{:., [], [{:&, [], [source_index]}, field]}, [], []} | _
               ]
             }
             | _
           ]
         } = query
       ) do
    query
    |> exclude(:select)
    |> select([{x, source_index}], struct(x, ^[field]))
    |> count()
  end

  defp aggregate(query) do
    query
    |> exclude(:select)
    |> select(count("*"))
  end

  defp get_operator_for_field(fields, key, direction) do
    {_, order} = Enum.find(fields, fn({field_key, _order}) -> field_key == key end)
    get_operator(order, direction)
  end

  defp get_operator(:asc, :before), do: :lt
  defp get_operator(:desc, :before), do: :gt
  defp get_operator(:asc, :after), do: :gt
  defp get_operator(:desc, :after), do: :lt

  defp get_operator(direction, _) do
    raise ArgumentError, "Invalid sorting value :#{direction}, use :asc or :desc"
  end

  defp maybe_where(query, %Config{after: nil, before: nil}) do
    query
  end

  defp maybe_where(query, %Config{after_values: after_values, before: nil, fields: fields}) do
    query
    |> filter_values(fields, after_values, :after)
  end

  defp maybe_where(query, %Config{after: nil, before_values: before_values, fields: fields}) do
    query
    |> filter_values(fields, before_values, :before)
    |> reverse_order_bys()
  end

  defp maybe_where(query, %Config{after_values: after_values, before_values: before_values, fields: fields}) do
    query
    |> filter_values(fields, after_values, :after)
    |> filter_values(fields, before_values, :before)
  end

  defp filter_values(query, fields, values, cursor_direction) do
    sorts =
      fields
      |> Keyword.keys()
      |> Enum.zip(values)
      |> Enum.reject(fn val -> match?({_column, nil}, val) end)

    dynamic_sorts =
      sorts
      |> Enum.with_index()
      |> Enum.reduce(true, fn {{bound_column, value}, i}, dynamic_sorts ->
        {position, column} = column_position(query, bound_column)

        dynamic = true

        dynamic =
          case get_operator_for_field(fields, bound_column, cursor_direction) do
            :lt -> dynamic([{q, position}], field(q, ^column) < ^value and ^dynamic)
            :gt -> dynamic([{q, position}], field(q, ^column) > ^value and ^dynamic)
          end

        dynamic =
          sorts
          |> Enum.take(i)
          |> Enum.reduce(dynamic, fn {prev_column, prev_value}, dynamic ->
            {position, prev_column} = column_position(query, prev_column)
            dynamic([{q, position}], field(q, ^prev_column) == ^prev_value and ^dynamic)
          end)

        if i == 0 do
          dynamic([{q, position}], ^dynamic and ^dynamic_sorts)
        else
          dynamic([{q, position}], ^dynamic or ^dynamic_sorts)
        end
      end)

    where(query, [{q, 0}], ^dynamic_sorts)
  end


  defp column_position(query, {binding_name, column}) do
    case Map.fetch(query.aliases, binding_name) do
      {:ok, position} ->
        {position, column}

      _ ->
        raise ArgumentError,
          "Could not find binding `#{binding_name}` in query aliases: #{inspect(query.aliases)}"
    end
  end

  defp column_position(_query, column) do
    {0, column}
  end

  defp query_limit(%Config{limit: limit}) do
    limit + 1
  end

  defp reverse_order_bys(query) do
    update_in(query.order_bys, fn
      [] ->
        []

      order_bys ->
        for %{expr: expr} = order_by <- order_bys do
          %{order_by | expr: Enum.map(expr, &reverse_order_by/1)}
        end
    end)
  end

  defp reverse_order_by({:desc, ast}) do
    {:asc, ast}
  end

  defp reverse_order_by({:asc, ast}) do
    {:desc, ast}
  end
end
