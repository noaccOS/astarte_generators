#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.Core.Generators.Interface do
  @moduledoc """
  This module provides generators for Astarte Interface.

  See https://docs.astarte-platform.org/astarte/latest/030-interface.html
  """
  use ExUnitProperties

  alias Astarte.Core.Generators.Interface
  alias Astarte.Core.Generators.Mapping, as: MappingGenerator
  alias Astarte.Core.Interface
  alias Ecto.UUID

  import ParameterizedStreams

  @doc """
  Generates a valid Astarte Interface.

  https://github.com/astarte-platform/astarte_core/blob/master/lib/astarte_core/interface.ex
  """
  @spec interface() :: StreamData.t(Interface.t())
  @spec interface(keyword()) :: StreamData.t(Interface.t())
  def interface(params \\ []) do
    gen all(
          required <- required_fields(params),
          optional <- optional_fields(params)
        ) do
      struct(Interface, Map.merge(required, optional))
    end
  end

  defp id, do: repeatedly(&UUID.bingenerate/0)

  defp name do
    string(:alphanumeric, min_length: 1, max_length: 16)
    |> list_of(
      min_length: 2,
      max_length: 5
    )
    |> filter(fn [<<first, _::binary>> | _] ->
      first < 48 or first > 57
    end)
    |> map(&Enum.join(&1, "."))
  end

  defp major_version, do: integer(0..9)
  defp minor_version(0 = _major_version), do: integer(1..255)
  defp minor_version(_major_version), do: integer(0..255)

  defp type, do: member_of([:datastream, :properties])

  defp ownership, do: member_of([:device, :server])

  defp mappings(config) do
    uniq_list_of(MappingGenerator.mapping(config), min_length: 1, max_length: 1000)
  end

  defp aggregation(%{type: :properties}), do: constant(:individual)
  defp aggregation(_), do: member_of([:individual, :object])

  defp description do
    string(:ascii, min_length: 1, max_length: 1000)
  end

  defp doc do
    string(:ascii, min_length: 1, max_length: 100_000)
  end

  defp endpoint_subpath do
    string([?a..?z, ?_], min_length: 1, max_length: 5)
  end

  @spec endpoint_parametric_subpath() :: StreamData.t(any())
  def endpoint_parametric_subpath do
    gen all(subpath <- endpoint_subpath()) do
      "%{" <> subpath <> "}"
    end
  end

  defp endpoint_prefix do
    gen all(
          prefix <-
            frequency([
              {1, endpoint_subpath()},
              {1, endpoint_parametric_subpath()}
            ])
            |> list_of(
              min_length: 1,
              max_length: 5
            )
            |> map(&Enum.join(&1, "/"))
        ) do
      "/" <> prefix
    end
  end

  defp required_fields(params) do
    gen all(
          id <- gen_param(id(), :id, params),
          name <- gen_param(name(), :name, params),
          major_version <- gen_param(major_version(), :major_version, params),
          minor_version <- gen_param(minor_version(major_version), :minor_version, params),
          type <- gen_param(type(), :type, params),
          aggregation <- gen_param(aggregation(%{type: type}), :aggregation, params),
          ownership <- gen_param(ownership(), :ownership, params),
          prefix <- gen_param(endpoint_prefix(), :prefix, params),
          retention <- gen_param(MappingGenerator.retention(), :retention, params),
          reliability <- gen_param(MappingGenerator.reliability(), :reliability, params),
          expiry <- gen_param(MappingGenerator.expiry(), :expiry, params),
          allow_unset <- gen_param(MappingGenerator.allow_unset(), :allow_unset, params),
          explicit_timestamp <-
            gen_param(MappingGenerator.explicit_timestamp(), :explicit_timestamp, params),
          mappings_args = %{
            aggregation: aggregation,
            prefix: prefix,
            retention: retention,
            reliability: reliability,
            expiry: expiry,
            allow_unset: allow_unset,
            explicit_timestamp: explicit_timestamp
          },
          mappings <- gen_param(mappings(mappings_args), :mappings, params)
        ) do
      %{
        id: id,
        interface_id: id,
        name: name,
        interface_name: name,
        major_version: major_version,
        minor_version: minor_version,
        version_major: major_version,
        version_minor: minor_version,
        type: type,
        interface_type: type,
        ownership: ownership,
        aggregation: aggregation,
        mappings: mappings
      }
    end
  end

  defp optional_fields(params) do
    gen all description <-
              gen_param(one_of([description(), constant(nil)]), :description, params),
            doc <- gen_param(one_of([doc(), constant(nil)]), :doc, params) do
      %{
        description: description,
        doc: doc
      }
    end
  end
end
