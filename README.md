# GeoRedi


An Elixir / Nif cache for geolocation addresses

geolocation data are stored in a Kd-tree.

## Example
  iex> 
  latitude = 49.496146587425265
  longitude = 0.12258659847596874
  fallback_fn = fn _lat,_lng -> "undefined" end  # fallback callback (e.g. to  nominatim)
  
  iex> GeoRedi.get_addr(latitude, longitude, , "undefined")
  "66, Rue Lesueur, Danton, 76600, Le Havre, Le Havre, France"}


## Installation

```elixir
def deps do
  [
    {:georedi, "~> 0.1.0"}
  ]
end
```
