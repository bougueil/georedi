defmodule Nif do
  @moduledoc """
  K-d_tree Nif module
  used to :
  - build the latitude, longitude coordinates and addresses tree
  - get the nearest address from latitude, longitude coordinates
  """
  @on_load :init

  app = Mix.Project.config()[:app]

  def init do
    path = :filename.join(:code.priv_dir(unquote(app)), 'nif')
    :ok = :erlang.load_nif(path, 0)
  end

  @doc """
  returns the nearest address along its best distance and time processed in microseconds.
  iex> Nif.nearest 586949738, -4559763
  {"Rue des Roquemonts, Folie-Couvrechef, 14000 Caen, France", 0, 40}
  Note: the best distance increases as the nearest point found is  distant but is not proportionel to the nearest point distance
  """
  @spec nearest(integer(), integer()) :: {binary(), integer(), float()} | {:error, atom()}
  def nearest(_lat, _lng) do
    exit(:nif_library_not_loaded)
  end

  @doc """
  Build a kd-tree with a list of coordinates and address and returns the number of addresses processed
  Example : 
  iex> new_tree [{{586949738, -4559763},  "Rue des Roquemonts, Folie-Couvrechef, 14000Caen, France"}]
  """
  @spec new_tree(list(tuple())) :: integer()
  def new_tree(latlngs) when is_list(latlngs) do
    exit(:nif_library_not_loaded)
  end

  def test() do
    list = :erlang.binary_to_term(File.read!("latlngs_sample"))
    list |> Nif.new_tree()
    Nif.nearest(439_660_087, -72_095_435)
  end

  def bench() do
    exit(:nif_library_not_loaded)
  end

  def debug() do
    exit(:nif_library_not_loaded)
  end

  def debug2(_, _) do
    exit(:nif_library_not_loaded)
  end

  def find_latlng(list, addr) do
    Enum.find(list, fn {_latlng, addr1} -> addr == addr1 end)
  end
end
