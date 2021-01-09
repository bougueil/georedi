defmodule GeoRedi.Worker do
  use GenServer
  use GeoRedi.Constants
  require Logger

  @moduledoc """
  Initialize the :addr ets table
  provides add_entry/4 api
  run background tasks
  """

  @refresh_live_cache_ms Application.get_env(:geo_redi, :refresh_live_cache_ms) ||
                           :timer.minutes(1)  # interval to rebuild the cache
  @clean_orphan_addr_every_ms :timer.hours(1) # interval for orphan addr gc
  @age_orphan_addr_ms :timer.hours(24)        # remove orphan addr older than that

  @doc """
  returns the fallback addr or fallback_not_found term as given in parameter
  """
  @spec add_entry(float(), float(), function(), binary() | term()) :: binary()
  def add_entry(lat, lng, fallback, fallback_not_found) do
    now = System.system_time()

    case fallback.(lat, lng) do
      ^fallback_not_found ->
        :exometer.update([:duration_us, :fallback_get], System.system_time() - now)
        fallback_not_found

      addr ->
        :exometer.update([:duration_us, :fallback_get], System.system_time() - now)
        now = System.system_time()
        insert_latlng(addr, GeoRedi.scale_31(lat), GeoRedi.scale_31(lng))

        :exometer.update([:duration_us, :write_cache], System.system_time() - now)
        addr
    end
  end

  @doc false
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(:addr, [:set, :named_table])
    GeoRedi.Backup.restore_from_disk()
    :redi.gc_client(:latlng, self(), %{returns: :key_value})
    restart_timer(@refresh_live_cache_ms, :refresh_live_cache)
    restart_timer(@clean_orphan_addr_every_ms, :clean_orphan_addr)
    Logger.info """
    #{__MODULE__} #{inspect(self())} init/1 with :  \
    \n\t@refresh_live_cache_ms #{@refresh_live_cache_ms} (#{div(@refresh_live_cache_ms,1000)} s.)\
    \n\t@clean_addr_after_ms #{@clean_addr_after_ms} (#{div(@clean_addr_after_ms,3600_000)} h.)\
    \n\t@clean_orphan_addr_every_ms every #{@clean_orphan_addr_every_ms}  (#{div(@clean_orphan_addr_every_ms,3600_000)} h.)
    """

    {:ok, %{tree: nil}}
  end

  defp insert_latlng(addr, lat, lng) do
    case :ets.lookup(:addr, addr) do
      [{_, {[{la1, ln1}, {la2, ln2} | _], _ts}}] ->
        latlngs = {round((la1 + la2 + lat) / 3), round((ln1 + ln2 + lng) / 3)}
        insert_addr({addr, latlngs})

      [{_, {{_lat, _lng}, _ts}}] ->
        :ok

      [] ->
        insert_addr({addr, [{lat, lng}]})

      [{_, {latlngs, _ts}}] ->
        insert_addr({addr, [{lat, lng} | latlngs]})
    end
  end

  defp insert_addr(kv = {addr, latlng}) do
    if is_tuple(latlng), do: :redi.set(:latlng, latlng, addr)
    GenServer.cast(__MODULE__, {:insert_addr, kv})
  end

  def insert_bulk_addr({addr, latlng}) do
    if is_tuple(latlng), do: :redi.set_bulk(:latlng, latlng, addr)
    :ets.insert(:addr, {addr, {latlng, ts_ms()}})
  end

  @impl true
  def handle_call({:insert_addr, {addr, latlng}}, _from, state) do
    :ets.insert(:addr, {addr, {latlng, ts_ms()}})
    {:reply, :ok, state}
  end

    @impl true
  def handle_cast({:insert_addr, {addr, latlng}}, state) do
    :ets.insert(:addr, {addr, {latlng, ts_ms()}})
    {:noreply, state}
  end

  @impl true
  def handle_info({:redi_gc, :latlng, keys}, state) do
    keys |> Enum.each(fn {_key, val} -> :ets.delete(:addr, val) end)
    {:noreply, state}
  end

  @impl true
  @doc """
  Time to re-actualize the kd tree with freshest lats/lngs
  """
  def handle_info(:refresh_live_cache = msg, state) do
    restart_timer(@refresh_live_cache_ms, msg)
    now = System.system_time()
    num_entries = GeoRedi.rebuild_live_cache()
    :exometer.update([:duration_us, :build_cache], System.system_time() - now)
    Logger.info("#{msg} cache #{num_entries} entries")

    {:noreply, state}
  end

  # Time to clean oldest addresses that couldn't be used by kd tree
  def handle_info(:clean_orphan_addr = msg, state) do
    restart_timer(@clean_orphan_addr_every_ms, msg)
    t_gc_ms = ts_ms() - @age_orphan_addr_ms
    ets_size = :ets.info :addr, :size
    now = System.system_time()
    num_cleaned =
      :ets.select_delete(:addr, [
        {{:"$1", {:"$2", :"$3"}}, [{:andalso, {:is_list, :"$2"}, {:<, :"$3", t_gc_ms}}], [true]}
      ])
    :exometer.update([:duration_us, :remove_old_addr], System.system_time() - now)

    Logger.error("#{msg} #{num_cleaned}/#{ets_size} old addresses hard removed in #{div(System.system_time() - now, 1000_000)} ms.")
    {:noreply, state}
  end

  @doc false
  def dump() do
    %{
      addr: :ets.tab2list(:addr),
      latlng: :ets.tab2list(:latlng),
      addr_size: :ets.info(:addr, :size),
      latlng_size: :ets.info(:latlng, :size)
    }
  end

  defp restart_timer(time, msg) do
    Process.send_after(self(), msg, time)
  end

  defp ts_ms(), do: System.system_time(:millisecond)
end
