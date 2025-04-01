defmodule ParameterizedStreams do
  @moduledoc """
  Utilities to allow creating parametric streams by allowing the user to override target values with
  custom values or generators
  """
  import StreamData

  @type stream() :: StreamData.t(term())

  @spec gen_param(stream(), atom(), keyword()) :: stream()
  def gen_param(default_gen, param_name, params) do
    case Keyword.fetch(params, param_name) do
      {:ok, value} ->
        if generator?(value), do: value, else: constant(value)

      :error ->
        default_gen
    end
  end

  # TODO: handle {stream(), stream()} type generators
  defp generator?(value) do
    is_struct(value, StreamData)
  end
end
