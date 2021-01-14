defmodule GeoRedi do
  require Logger

  @moduledoc """
  GeoRedi is a geospatial address cache based on the [k-d tree](https://en.wikipedia.org/wiki/K-d_tree) algorithm.

  `GeoRedi.get_addr(latitude, longitude, \

  fallback, "fallback_notfound)` returns a tuple :


  `{address, best_distance, ms}`.

  Internally, if no address is found with an acceptable best_distance, see configurable parameter `:nearest_dist_max`, the `fallback` fun is called with latitude, longitude and returns either `fallback_not_found` or an address that GeoRedi adds it to the cache.

  The cached addresses will be discarted after the configurable `:clean_addr_after_ms` parameter, enabling some 'data refreshing' or limiting the cache from being too large.


  The cache lookup time is O(log n) thanks to the K-d tree.

  The cache update has a cost in time and should be done at regular intervals, see the config parameter `:refresh_live_cache_ms` for more details.


  ## Usage

      iex> GeoRedi.get_addr(49.496146587425265, 0.12258659847596874, fn _,_ -> "undefined" end, "undefined")
      "undefined"

  returns "undefined", the default callback value

  ## Configuration


  - `:refresh_live_cache_ms` - update cache in ms, default is 1 minute, 

  - `:clean_addr_after_ms` - keep data in cache in ms, default is 14 days

  - `:nearest_dist_max` - default is 36000000 for GeoRedi to accept a nearest address less than 20-30m   
  if you want the double distance, use (4 * nearest_dist_max = 144000000)

  """

  @doc """
  returns either a tuple containing :
  - the address from geolocation latitude, longitude; 
  - the best_distance;
  - computaion time in microseconds.

  or the term fallback_not_found given in parameter.


  latitude and longitude are expressed in degree

  First GeoRedi gets the cached address if any or calls fallback/2.

  ## Example


      iex> GeoRedi.get_addr(49.496146587, 0.12258659, fn _,_ -> "undefined" end, "undefined")
      "undefined"

  returns the nearest_address.

  """

  @nearest_dist_max Application.get_env(:geo_redi, :nearest_dist_max) || 6000 * 6000

  @spec get_addr(
          latitude :: float(),
          longitude :: float(),
          fallback_fn :: function(),
          fallback_not_found :: binary() | term()
        ) :: tuple() | binary() | term()
  def get_addr(lat, lng, fallback, fallback_not_found)
      when is_float(lat) and is_float(lng) and is_function(fallback, 2) do
    now = System.system_time()

    case Nif.nearest(scale_31(lat), scale_31(lng)) do
      {addr, dist, _time} when dist < @nearest_dist_max ->
        :exometer.update([:duration_us, :read_cache], System.system_time() - now)
	:exometer.update([:hit, :cache_1day], 1)
	:exometer.update([:hit, :cache_10mn], 1)
        # Logger.info("{found_cache, #{lat},#{lng},#{dist},#{addr}")
        addr
      _ ->
	:exometer.update([:hit, :fallback_1day], 1)
	:exometer.update([:hit, :fallback_10mn], 1)
        GeoRedi.Worker.add_entry(lat, lng, fallback, fallback_not_found)
    end
  end

  def get_addr(_lat, _lng, _fallback, fallback_not_found), do: fallback_not_found


  @doc """
  Rebuild the kd tree
  Returns the cache's number of entries
  """
  def rebuild_live_cache() do
     :ets.tab2list(:latlng) |>  Nif.new_tree()
  end


  @doc """
  returns some stats on the cache efficiency
  """
  def stats(), do: GeoRedi.Application.stats()

  @mult 11_930_464
  @doc false
  def scale_31(angle), do: round(angle * @mult)

  @doc false
  def unscale_31(angle), do: angle / @mult

  # returns the {lat, lng} of an address
  # for debug purpose
  @doc false
  def debug_latlng(addr) do
    case Enum.find(:ets.tab2list(:latlng), fn {_latlngs, addr1} -> addr1 == addr end) do
      {{lat, lng}, _addr} ->
        {lat / @mult, lng / @mult}

      other ->
        other
    end
  end

  # returns the dist between 2 points as returned by Nif.nearest/2
  # for debug purpose 
  @doc false
  def debug_best_dist({la1, ln1}, {la2, ln2}) do
    :math.pow(la2 - la1, 2) + :math.pow(ln2 - ln1, 2)
  end

  @doc false
  def debug_best_dist(best_dist) do
    delta_deg = :math.sqrt(best_dist) / 11_930_464
    [delta_deg: delta_deg, delta_rad: :math.pi() * delta_deg / 180]
  end

  @doc """
  compare addresses between cache and fallback
  """
  def diff_local_fallback(fallback, limit \\ 100) do
    mismatches = :ets.tab2list :latlng |> Enum.take(limit)
    |> Enum.reduce(0, fn {{lat, lng}, addr}, cnt ->
      addr_fb = fallback.(GeoRedi.unscale_31(lat), GeoRedi.unscale_31(lng))
      if addr != addr_fb do
	IO.puts "mismatch #{GeoRedi.unscale_31(lat)}, #{GeoRedi.unscale_31(lng)}: \n\t#{addr}\n\t#{addr_fb}"
	cnt + 1
      else
	cnt
      end
    end)
    IO.puts "#{mismatches} mismatches out of #{limit}"
  end

end
