defmodule GeoRediTest do
  use ExUnit.Case
  doctest GeoRedi

  test "no data in cache" do
    assert GeoRedi.get_addr(
             59.496146587425265,
             0.12258659847596874,
             fn _, _ -> "undefined" end,
             "undefined"
           ) == "undefined"
  end
end
