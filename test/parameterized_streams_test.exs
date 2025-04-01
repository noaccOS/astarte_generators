defmodule ParameterizedStreamsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import ParameterizedStreams

  describe "gen_param/3" do
    property "returns the default generator when the value is not being overridden" do
      check all default_generator <- generator(),
                param_not_in_user_params <- atom(:alphanumeric),
                user_params <- keyword_of(one_of([generator(), term()])),
                user_params = Keyword.delete(user_params, param_not_in_user_params) do
        assert gen_param(default_generator, param_not_in_user_params, user_params) ==
                 default_generator
      end
    end

    property "returns the custom generator when the value is being overridden with a generator" do
      check all default_generator <- generator(),
                user_params <- list_of({atom(:alphanumeric), generator()}, min_length: 1) do
        {param, custom_gen} = List.first(user_params)
        assert gen_param(default_generator, param, user_params) == custom_gen
      end
    end

    property "always returns the custom value when the value is being overridden with a constant" do
      check all default_generator <- generator(),
                user_params <- list_of({atom(:alphanumeric), term()}, min_length: 1),
                {param, custom_value} = List.first(user_params),
                generated_value <- gen_param(default_generator, param, user_params) do
        assert generated_value == custom_value
      end
    end
  end

  describe "generators using gen_param/3" do
    property "generate correctly with default parameters" do
      check all a <- a() do
        refute is_nil(a)
      end
    end

    property "can have their values overridden with a constant" do
      check all id <- integer(),
                b <- list_of(b()),
                a <- a(id: id, b: b) do
        assert a.id == id
        assert a.b == b
      end
    end

    property "can have their values overridden with a custom generator" do
      check all a <- a(b: string(:printable)) do
        assert is_binary(a.b)
      end
    end

    property "can be overridden when used as parameters for other generators" do
      check all id <- integer(),
                a <- a(b: fixed_list([b(id: id)])) do
        assert [b] = a.b
        assert b.id == id
      end
    end

    property "can be overridden when used as parameters for other generators two levels deep" do
      check all c_id <- integer(),
                a <- a(b: list_of(b(c: list_of(c(id: constant(c_id)))))) do
        c = a.b |> Enum.flat_map(& &1.c)
        assert Enum.all?(c, &(&1.id == c_id))
      end
    end
  end

  defp a(params \\ []) do
    gen all id <- gen_param(integer(), :id, params),
            b <- gen_param(list_of(b(), max_length: 3), :b, params) do
      %{id: id, b: b}
    end
  end

  defp b(params \\ []) do
    gen all id <- gen_param(integer(), :id, params),
            c <- gen_param(list_of(c(), max_length: 3), :c, params) do
      %{id: id, c: c}
    end
  end

  defp c(params \\ []) do
    gen all id <- gen_param(integer(), :id, params) do
      %{id: id}
    end
  end

  defp generator do
    member_of([
      atom(:alphanumeric),
      atom(:alias),
      bitstring(),
      boolean(),
      byte(),
      chardata(),
      codepoint(),
      bind(term(), &constant/1),
      float(),
      integer(),
      iodata(),
      iolist(),
      keyword_of(term()),
      list_of(term()),
      map_of(term(), term()),
      mapset_of(term()),
      maybe_improper_list_of(term(), term()),
      member_of(list_of(term(), min_length: 1) |> Enum.at(0)),
      non_negative_integer(),
      positive_integer(),
      string(:ascii),
      string(:alphanumeric),
      string(:printable),
      string(:utf8),
      term(),
      tuple({term(), term()}),
      tuple({term(), term(), term()}),
      tuple({term(), term(), term(), term()}),
      uniq_list_of(term())
    ])
  end
end
