defmodule Ouroboros.Page.Metadata do
  @moduledoc """
  Defines page metadata.

  ## Fields

  * `after` - cursor representing the last row of the current page;
  * `before` - cursor representing the first row of the current page;
  * `total` - total number of entries;
  * `limit` - the maximum number of entries that can be contained in this page.

  """

  @type t :: %__MODULE__{
    after: binary(),
    before: binary(),
    limit: non_neg_integer(),
    total: integer() | nil,
  }

  defstruct [:after, :before, :limit, :total]
end
