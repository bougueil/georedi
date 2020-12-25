# GeoRedi


An Elixir / Nif cache for geolocation addresses.

geolocation data are stored in a Kd-tree.

## Example      
      iex> lat = 49.496146587425265; lng = 0.12258659847596874
      0.12258659847596874
      
      iex> callback_fn = fn lat, lng -> Process.sleep(500); "ADDR_#{lat}_#{lng}" end
      
      iex> GeoRedi.get_addr(lat, lng, callback_fn, "undefined")
      "ADDR_49.496146587425265_0.12258659847596874"


## Installation
```elixir
def application do
  [
    extra_applications: [
	..
	:georedi
    ]
  ]
end

def deps do
  [
    {:georedi, "~> 0.1.0"}
  ]
end
```
