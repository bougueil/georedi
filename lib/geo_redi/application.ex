defmodule GeoRedi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
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
    Enum.each(histograms(), fn name ->
      :ok =
        :exometer.new(name, :histogram, [
          {:time_span, :timer.seconds(120)},
          {:slot_period, :timer.seconds(1)}
        ])
    end)
  end

  defp histograms() do
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
    read_cache = elem(hd(:exometer.get_values([:duration_us, :read_cache])), 1)[:n]
    fallback_get = elem(hd(:exometer.get_values([:duration_us, :fallback_get])), 1)[:n]

    {for name <- histograms() do
       :exometer.get_values(name)
     end,
     ratio_cache: read_cache * 100 / (read_cache + fallback_get), size: :ets.info(:latlng, :size)}
  end
end
