defmodule GeoRedi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  @clean_ets_addr_after_ms Application.get_env(:geo_redi, :clean_ets_addr_after_ms) ||
                             :timer.hours(24 * 14)

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
             %{bucket_name: :latlng, entry_ttl_ms: @clean_ets_addr_after_ms}
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
    [{_, [_, one: hit_cache_1day]}] = :exometer.get_values([:hit, :cache_1day])
    [{_, [_, one: hit_fallback_1day]}] = :exometer.get_values([:hit, :fallback_1day])
    [{_, [_, one: hit_cache_10mn]}] = :exometer.get_values([:hit, :cache_10mn])
    [{_, [_, one: hit_fallback_10mn]}] = :exometer.get_values([:hit, :fallback_10mn])
    durations = for name <- exom_durations(), do: :exometer.get_values(name)
    [
      durations: durations,
      hit_cache_1day: hit_cache_1day,
      hit_cache_10mn: hit_cache_10mn,
      hit_fallback_1day: hit_fallback_1day,
      hit_fallback_10mn: hit_fallback_10mn,
      ratio_cache_1day: safe_percent(hit_cache_1day, hit_fallback_1day + hit_cache_1day),
      ratio_cache_10mn: safe_percent(hit_cache_10mn, hit_fallback_10mn + hit_cache_10mn),
      size_latlng: :ets.info(:latlng, :size),
      size_addr: :ets.info(:addr, :size)
    ]
  end
  defp safe_percent(val, divisor) when divisor != 0, do: val * 100 / divisor
  defp safe_percent(_val, _divisor),  do: 0.0
end
