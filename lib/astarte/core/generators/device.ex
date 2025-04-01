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

defmodule Astarte.Core.Generators.Device do
  @moduledoc """
  This module provides generators for Astarte Device.

  See https://hexdocs.pm/astarte_core/Astarte.Core.Device.html

  """
  use ExUnitProperties
  alias Astarte.Common.Generators.Ip, as: IpGenerator
  alias Astarte.Common.Generators.Timestamp, as: TimestampGenerator
  alias Astarte.Core.Device
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  import ParameterizedStreams

  @doc """
  Generates a valid Astarte Device with pre-created interfaces_bytes
  TODO: using `ecto_strea_factory` in the future
  """
  @spec device() :: StreamData.t(map())
  @spec device(keyword()) :: StreamData.t(map())
  def device(params \\ []) do
    gen all id <- gen_param(id(), :id, params),
            last_seen_ip <- gen_param(IpGenerator.ip(:ipv4), :last_seen_ip, params),
            last_credentials_request_ip <-
              gen_param(IpGenerator.ip(:ipv4), :last_credentials_request_ip, params),
            inhibit_credentials_request <-
              gen_param(boolean(), :inhibit_credentials_request, params),
            {
              first_registration,
              first_credentials_request,
              last_connection,
              last_disconnection
            } <- dates(params),
            interfaces <-
              gen_param(
                uniq_list_of(InterfaceGenerator.interface(),
                  uniq_fun: &{&1.name, &1.major_version}
                ),
                :interfaces,
                params
              ),
            interfaces_msgs <- gen_param(interfaces_msgs(interfaces), :interfaces_msgs, params),
            interfaces_bytes <-
              gen_param(interfaces_bytes(interfaces), :interfaces_bytes, params),
            aliases <- gen_param(aliases(), :aliases, params),
            attributes <- gen_param(attributes(), :attributes, params) do
      total_received_msgs = interfaces_msgs |> Map.values() |> Enum.sum()
      total_received_bytes = interfaces_bytes |> Map.values() |> Enum.sum()

      %{
        id: id,
        device_id: id,
        encoded_id: Device.encode_device_id(id),
        connected: last_connection >= last_disconnection,
        first_registration: first_registration,
        first_credentials_request: first_credentials_request,
        last_connection: last_connection,
        last_disconnection: last_disconnection,
        last_seen_ip: last_seen_ip,
        inhibit_credentials_request: inhibit_credentials_request,
        last_credentials_request_ip: last_credentials_request_ip,
        interfaces_msgs: interfaces_msgs,
        interfaces_bytes: interfaces_bytes,
        aliases: aliases,
        attributes: attributes,
        total_received_msgs: total_received_msgs,
        total_received_bytes: total_received_bytes
      }
    end
  end

  @doc """
  Generates a valid Astarte Device id

  See https://docs.astarte-platform.org/astarte/latest/010-design_principles.html#device-id
  """
  @spec id() :: StreamData.t(<<_::128>>)
  def id do
    gen all seq <- binary(length: 16) do
      <<u0::48, _::4, u1::12, _::2, u2::62>> = seq
      <<u0::48, 4::4, u1::12, 2::2, u2::62>>
    end
  end

  @doc """
  Generates a valid Astarte encoded Device id
  """
  @spec encoded_id() :: StreamData.t(String.t())
  def encoded_id do
    gen all id <- id() do
      Base.url_encode64(id, padding: false)
    end
  end

  # Interface utility functions
  defp interface_key(interface), do: {interface.name, interface.major_version}

  defp interfaces_msgs(interfaces) do
    interfaces
    |> Enum.map(&interface_key/1)
    |> Map.new(&{&1, integer(1..10_000)})
    |> fixed_map()
  end

  defp interfaces_bytes(interfaces) do
    interfaces
    |> Enum.map(&interface_key/1)
    |> Map.new(&{&1, integer(10..10_000)})
    |> fixed_map()
  end

  defp aliases do
    [
      map_of(string(:alphanumeric, min_length: 1), string(:alphanumeric, min_length: 1)),
      constant(nil)
    ]
    |> one_of()
  end

  defp attributes do
    [
      map_of(
        string(:alphanumeric, min_length: 1),
        string(:alphanumeric, min_length: 1)
      ),
      constant(nil)
    ]
    |> one_of()
  end

  defp dates(params) do
    now = "Etc/UTC" |> DateTime.now!() |> DateTime.to_unix()

    gen all last_disconnection <-
              gen_param(TimestampGenerator.timestamp(max: now), :last_disconnection, params),
            last_connection <-
              gen_param(
                TimestampGenerator.timestamp(max: last_disconnection),
                :last_connection,
                params
              ),
            first_credentials_request <-
              gen_param(
                TimestampGenerator.timestamp(max: last_connection),
                :first_credentials_request,
                params
              ),
            first_registration <-
              gen_param(
                TimestampGenerator.timestamp(max: first_credentials_request),
                :first_registration,
                params
              ) do
      {
        first_registration,
        first_credentials_request,
        last_connection,
        last_disconnection
      }
    end
  end
end
