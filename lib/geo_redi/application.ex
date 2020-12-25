defmodule GeoRedi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    declare_exometer_durations()
    declare_exometer_counters()

    children = [
      %{
        id: :latlng,
        start:
          {:redi, :start_link,
           [
             :latlng,
             %{bucket_name: :latlng, entry_ttl_ms: :timer.hours(24 * 10)}
           ]}
      },
      {GeoRedi.Worker, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GeoRedi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp declare_exometer_counters() do
    for {name, slot_period} <- exom_counters() do
      :ok =
        :exometer.new(name, :spiral, [
          {:time_span, :timer.seconds(slot_period * 120)},
          {:slot_period, :timer.seconds(slot_period)}
        ])
    end
  end

  defp declare_exometer_durations() do
    for name <- exom_durations() do
      :ok =
        :exometer.new(name, :histogram, [
          {:time_span, :timer.seconds(120)},
          {:slot_period, :timer.seconds(1)}
        ])
    end
  end

  defp exom_counters() do
    [
      {[:hit, :fallback_10mn], 10},
      {[:hit, :cache_10mn], 10},
      {[:hit, :fallback_1day], div(24*3600, 120)},
      {[:hit, :cache_1day], div(24 * 3600, 120)}
    ]
  end

  defp exom_durations() do
    [
      [:duration_us, :fallback_get],
      [:duration_us, :build_cache],
      [:duration_us, :read_cache],
      [:duration_us, :write_cache]
    ]
  end

  @doc """
  returns some stats 
  """
  def stats() do
    hit_cache = elem(hd(:exometer.get_values([:hit, :cache])), 1)[:n]
    hit_fallback = elem(hd(:exometer.get_values([:hit, :fallback])), 1)[:n]
    durations = for name <- exom_durations(), do: :exometer.get_values(name)
    [
      durations: durations,
      ratio_cache: hit_cache * 100 / hit_fallback,
      size_latlng: :ets.info(:latlng, :size),
      size_addr: :ets.info(:addr, :size)
    ]
  end
end
