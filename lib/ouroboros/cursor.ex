defmodule Ouroboros.Cursor do
  @moduledoc false

  def decode(_, value) when value in [nil, ""] do
    nil
  end

  def decode(types, encoded_cursor) do
    fields =
      encoded_cursor
      |> Base.url_decode64!(padding: false)
      |> :erlang.binary_to_term([:safe])

    types
    |> Enum.zip(fields)
    |> Enum.map(&decode_type/1)
  end

  defp decode_type({:utc_datetime, value}) when is_integer(value) do
    DateTime.from_unix!(value, :second)
  end

  defp decode_type({:utc_datetime_usec, value}) when is_integer(value) do
    DateTime.from_unix!(value, :microsecond)
  end

  defp decode_type({_type, value}) do
    value
  end

  def encode(value) do
    value
    |> List.wrap()
    |> Enum.map(&encode_type/1)
    |> :erlang.term_to_binary()
    |> Base.url_encode64(padding: false)
  end

  defp encode_type({:utc_datetime, %DateTime{} = value}) do
    DateTime.to_unix(value, :second)
  end

  defp encode_type({:utc_datetime_usec, %DateTime{} = value}) do
    DateTime.to_unix(value, :microsecond)
  end

  defp encode_type({_type, value}) do
    value
  end
end
