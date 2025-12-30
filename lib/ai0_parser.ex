defmodule Ai0Parser do
  @moduledoc """
  Simple wrapper for parsing AI0 TXT files and producing JSON.
  """

  alias Ai0Parser.Parser

  def parse_string(s) when is_binary(s), do: Parser.parse(s)

  def to_json(data), do: Jason.encode!(data, pretty: true)
end
