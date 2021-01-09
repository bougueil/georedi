defmodule GeoRediTest do
  use ExUnit.Case
  doctest GeoRedi

  test "no data in cache" do
    inc = 0.000001

    lat = 1.00001
    lng = 2.00001
    addr = fallback lat, lng

    assert GeoRedi.get_addr(lat, lng, &fallback/2, nil) == addr
    IO.inspect :ets.tab2list( :addr), label: "addr 1"

    assert GeoRedi.get_addr(lat+inc, lng, &fallback/2, nil) == addr
    IO.inspect :ets.tab2list( :addr), label: "addr 2"

    assert GeoRedi.get_addr(lat, lng+inc, &fallback/2, nil) == addr
    IO.inspect :ets.tab2list( :addr), label: "addr 3"
    num_items =  GeoRedi.rebuild_live_cache()
    IO.puts "rebuild_live_cache #{num_items}"
    IO.inspect :ets.tab2list( :latlng), label: "latlng"
    IO.inspect :ets.tab2list( :addr), label: "addr"
  end

  def fallback(lat,lng) when is_float(lat) and is_float(lng) do
    Process.sleep(100); "ADDR_#{decimal_5(lat)}_#{decimal_5(lng)}"
  end

  def decimal_5(val), do: :erlang.float_to_binary(val, decimals: 4)

end
