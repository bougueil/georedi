# GeoRedi


An Elixir / Nif cache for geolocation addresses.

geolocation data are stored in a Kd-tree.

## Example      
      iex> latitude = 49.496146587425265; longitude = 0.12258659847596874
      0.12258659847596874
      
      iex> nominatim_fn = fn lat, lng -> nominatim(lat,lng) end  # fallback callback
      
      iex> GeoRedi.get_addr(latitude, longitude, nominatim_fn, "undefined")
      "66, Rue Lesueur, Danton, 76600, Le Havre, Le Havre, France"}


## Installation

```elixir
def deps do
  [
    {:georedi, "~> 0.1.0"}
  ]
end
```
