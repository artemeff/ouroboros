defmodule Ouroboros do
  @moduledoc """
  Allows you to paginate your Ecto results using cursors.

  ## Usage

      defmodule MyApp.Repo do
        use Ecto.Repo, otp_app: :my_app
        use Ouroboros
      end

  ## Options

  `Ouroboros` can take any options accepted by `paginate/3`. This is useful when
  you want to enforce some options globally across your project.

  ### Example

      defmodule MyApp.Repo do
        use Ecto.Repo, otp_app: :my_app
        use Ouroboros, limit: 10, limit_max: 100,
      end

  Note that these values can be still be overriden when `paginate/3` is called.

  ### Use without macros

  If you wish to avoid use of macros or you wish to use a different name for
  the pagination function you can define your own function like so:

      defmodule MyApp.Repo do
        use Ecto.Repo, otp_app: :my_app

        def my_paginate_function(query, opts \\ [], repo_opts \\ []) do
          defaults = [limit: 10] # Default options of your choice here
          opts = Keyword.merge(defaults, opts)
          Ouroboros.paginate(query, opts, __MODULE__, repo_opts)
        end
      end

  """

  alias Ouroboros.{Ecto.Query, Config, Cursor, Page, Page.Metadata}

  defmacro __using__(opts) do
    quote do
      @defaults unquote(opts)

      def paginate(query, opts \\ [], repo_opts \\ []) do
        Ouroboros.paginate(query, Keyword.merge(@defaults, opts), __MODULE__, repo_opts)
      end
    end
  end

  @doc """
  Fetches all the results matching the query within the cursors.

  ## Options

    * `:after` - fetch the records after this cursor;
    * `:before` - fetch the records before this cursor;
    * `:fields` - fields with sorting direction used to determine the cursor.
      In most cases, this should be the same fields as the ones used for sorting in the query.
      When you use named bindings in your query they can also be provided;
    * `:value_fun` - function of arity 2 to lookup cursor values on returned records.
      Defaults to `&Ouroboros.value_fun_default/2`;
    * `:limit` - limits the number of records returned per page. Note that this
      number will be capped by `:limit_max`. Defaults to `50`;
    * `:limit_max` - sets a maximum cap for `:limit`. This option can be useful when `:limit`
      is set dynamically (e.g from a URL param set by a user) but you still want to
      enfore a maximum. Defaults to `100`.

  ## Repo options

  This will be passed directly to `Ecto.Repo.all/2`, as such any option supported
  by this function can be used here.

  ## Simple example

      query = from(p in Post, order_by: [asc: p.inserted_at, asc: p.id], select: p)

      Repo.paginate(query, fields: [:inserted_at, :id], limit: 50)

  ## Example with using custom sort directions per field

      query = from(p in Post, order_by: [asc: p.inserted_at, desc: p.id], select: p)

      Repo.paginate(query, fields: [inserted_at: :asc, id: :desc], limit: 50)

  ## Example with sorting on columns in joined tables

      from p in Post, as: :posts,
        join: a in assoc(p, :author), as: :author,
        preload: [author: a],
        select: p,
        order_by: [asc: a.name, asc: p.id]

      Repo.paginate(query, fields: [{{:author, :name}, :asc}, id: :asc], limit: 50)

  When sorting on columns in joined tables it is necessary to use named bindings. In
  this case we name it `author`. In the `fields` we refer to this named binding
  and its column name.

  To build the cursor Ouroboros uses the returned Ecto.Schema. When using a joined
  column the returned Ecto.Schema won't have the value of the joined column
  unless we preload it. E.g. in this case the cursor will be build up from
  `post.id` and `post.author.name`. This presupposes that the named of the
  binding is the same as the name of the relationship on the original struct.

  One level deep joins are supported out of the box but if we join on a second
  level, e.g. `post.author.company.name` a custom function can be supplied to
  handle the cursor value retrieval. This also applies when the named binding
  does not map to the name of the relationship.

  ## Example

      from p in Post, as: :posts,
        join: a in assoc(p, :author), as: :author,
        join: c in assoc(a, :company), as: :company,
        preload: [author: a],
        select: p,
        order_by: [
          {:asc, a.name},
          {:asc, p.id}
        ]

      Repo.paginate(query,
        fields: [{{:company, :name}, :asc}, id: :asc],
        value_fun: fn
          post, {{:company, name}, _} -> {:string, post.author.company.name}
          post, field -> Ouroboros.value_fun_default(post, field)
        end, limit: 50)

  """
  @callback paginate(query :: Ecto.Query.t(), opts :: keyword(), repo_opts :: keyword()) :: Ouroboros.Page.t()

  @doc false
  def paginate(query, opts, repo, repo_opts) do
    config = Config.new(query, opts)

    unless config.fields do
      raise ArgumentError,
        "expected `:fields` to be set in call to paginate/4"
    end

    {sorted_entries, paginated_entries} =
      if config.limit == 0 do
        {[], []}
      else
        sorted_entries = repo.all(Query.paginate(query, config), repo_opts)
        paginated_entries = paginate_entries(sorted_entries, config)

        {sorted_entries, paginated_entries}
      end

    %Page{
      entries: paginated_entries,
      metadata: %Metadata{
        before: before_cursor(paginated_entries, sorted_entries, config),
        after: after_cursor(paginated_entries, sorted_entries, config),
        limit: config.limit,
        total: maybe_query_total(repo, repo_opts, query, config)
      }
    }
  end

  @doc """
  Generate a cursor for the supplied record, in the same manner as the
  `before` and `after` cursors generated by `paginate/3`.

  For the cursor to be compatible with `paginate/3`, `fields`
  must have the same value as the `fields` option passed to it.

  ### Example

      iex> Ouroboros.cursor_for_record(%Ouroboros.Customer{id: 1}, [:id])
      "g2sAAQE"

      iex> Ouroboros.cursor_for_record(%Ouroboros.Customer{id: 1, name: "Alice"}, [id: :asc, name: :desc])
      "g2wAAAACYQFtAAAABUFsaWNlag"

  """
  @spec cursor_for_record(any(), [atom], (map(), atom() | {atom(), atom()} -> any())) :: binary()
  def cursor_for_record(record, fields, value_fun \\ &value_fun_default/2) do
    fetch_cursor_value(record, %Config{
      fields: fields,
      value_fun: value_fun
    })
  end

  @doc """
  Default function used to get the value of a cursor field from the supplied
  map. This function can be overriden in the `Ouroboros.Config` using the `value_fun` key.

  When using named bindings to sort on joined columns it will attempt to get
  the value of joined column by using the named binding as the name of the
  relationship on the original Ecto.Schema.

  ### Example

      iex> Ouroboros.value_fun_default(%Ouroboros.Customer{id: 1}, :id)
      {:id, 1}

      iex> Ouroboros.value_fun_default(%Ouroboros.Customer{id: 1, address: %Ouroboros.Address{city: "London"}}, {:address, :city})
      {:string, "London"}

  """

  @spec value_fun_default(map(), atom() | {atom(), atom()}) :: term()
  def value_fun_default(schema, {binding, field}) when is_atom(binding) and is_atom(field) do
    if Map.has_key?(schema, field) do
      value_fun_default(schema, field)
    else
      value_fun_default(Map.get(schema, binding), field)
    end
  end

  def value_fun_default(schema, field) when is_atom(field) do
    {type_fun_default(schema, field), Map.get(schema, field)}
  end

  @doc """
  Default function used to get the value of a cursor field from the supplied
  map. This function can be overriden in the `Ouroboros.Config` using the `value_fun` key.

  When using named bindings to sort on joined columns it will attempt to get
  the value of joined column by using the named binding as the name of the
  relationship on the original Ecto.Schema.

  ### Example

      iex> Ouroboros.type_fun_default(%Ouroboros.Customer{id: 1}, :id)
      :id

      iex> Ouroboros.type_fun_default(%Ouroboros.Customer{}, {:address, :city})
      :string

      iex> Ouroboros.type_fun_default(%Ouroboros.Customer{id: 1, address: %Ouroboros.Address{city: "London"}}, {:address, :city})
      :string

      iex> Ouroboros.type_fun_default(Ouroboros.Customer, :inserted_at)
      :naive_datetime

  """

  def type_fun_default(nil, _field) do
    nil
  end

  def type_fun_default(%_{} = schema, {binding, field}) when is_atom(binding) and is_atom(field) do
    if Map.has_key?(schema, field) do
      type_fun_default(schema, field)
    else
      type_fun_default(Map.get(schema, binding), field)
    end
  end

  def type_fun_default(%Ecto.Association.NotLoaded{__owner__: module, __field__: binding}, field) do
    type_fun_default(module.__schema__(:association, binding).related, field)
  end

  def type_fun_default(%module{}, field) do
    type_fun_default(module, field)
  end

  def type_fun_default(module, field) when is_atom(module) and is_atom(field) do
    module.__schema__(:type, field)
  end

  defp maybe_query_total(repo, repo_opts, query, %Config{total: true}) do
    repo.one(Query.count(query), repo_opts)
  end

  defp maybe_query_total(_repo, _repo_opts, _query, %Config{}) do
    nil
  end

  defp paginate_entries(sorted_entries, %Config{before: before, after: nil, limit: limit}) when not is_nil(before) do
    sorted_entries
    |> Enum.take(limit)
    |> Enum.reverse()
  end

  defp paginate_entries(sorted_entries, %Config{limit: limit}) do
    Enum.take(sorted_entries, limit)
  end

  defp before_cursor([], [], _config) do
    nil
  end

  defp before_cursor(_paginated_entries, _sorted_entries, %Config{after: nil, before: nil}) do
    nil
  end

  defp before_cursor(paginated_entries, _sorted_entries, %Config{after: cafter} = config) when not is_nil(cafter) do
    first_or_nil(paginated_entries, config)
  end

  defp before_cursor(paginated_entries, sorted_entries, %Config{} = config) do
    if first_page?(sorted_entries, config) do
      nil
    else
      first_or_nil(paginated_entries, config)
    end
  end

  defp first_or_nil([], %Config{}) do
    nil
  end

  defp first_or_nil([first | _], %Config{} = config) do
    fetch_cursor_value(first, config)
  end

  defp after_cursor([], [], _config) do
    nil
  end

  defp after_cursor(paginated_entries, _sorted_entries, %Config{before: before} = config) when not is_nil(before) do
    last_or_nil(paginated_entries, config)
  end

  defp after_cursor(paginated_entries, sorted_entries, %Config{} = config) do
    if last_page?(sorted_entries, config) do
      nil
    else
      last_or_nil(paginated_entries, config)
    end
  end

  defp last_or_nil([], %Config{}) do
    nil
  end

  defp last_or_nil(entries, %Config{} = config) do
    fetch_cursor_value(List.last(entries), config)
  end

  defp fetch_cursor_value(schema, %Config{fields: fields, value_fun: value_fun}) do
    fields
    |> Enum.map(fn
         ({field, order}) when order in [:asc, :desc] -> value_fun.(schema, field)
         (field) -> value_fun.(schema, field)
       end)
    |> Cursor.encode()
  end

  defp first_page?(sorted_entries, %Config{limit: limit}) do
    length(sorted_entries) <= limit
  end

  defp last_page?(sorted_entries, %Config{limit: limit}) do
    length(sorted_entries) <= limit
  end
end
