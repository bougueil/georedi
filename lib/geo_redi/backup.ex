defmodule GeoRedi.Backup do
  require Logger

  @georedi_bck_file "georedi_bckup"

  @moduledoc """
  in charge of saving / restore the on dish.
  """

  @doc """
  Save the cache on disk.
  There is no automatic saving, it has to be performed manually
  """
  def save_on_disk() do
    fname = filename_with_date(@georedi_bck_file)
    tables_bk = tables() |> Enum.map(fn ta -> {ta, :ets.tab2list(ta)} end)

    File.write!(fname, :erlang.term_to_binary({Node.self(), tables_bk}))
    Logger.info("backup in #{@georedi_bck_file} #{length(tables_bk)} table(s).")
    File.rm(@georedi_bck_file)
    File.ln_s(fname, @georedi_bck_file)
  end

  @doc """
  Restore the cache on disk.
  Called at the start of the application
  """
  def restore_from_disk() do
    if File.exists?(@georedi_bck_file) do
      do_restore_from_file(@georedi_bck_file)
    else
      Logger.info("restore file not found (#{@georedi_bck_file})")
    end
  end

  defp tables(), do: [:latlng, :addr]

  defp do_restore_from_file(path) do
    {node, tables_bk} = File.read!(path) |> :erlang.binary_to_term()

    tables_bk
    |> Enum.each(fn
      {:addr, content} ->
        Enum.each(
          content,
          fn {addr, {latlng, _}} ->
            GeoRedi.Worker.insert_bulk_addr({addr, latlng})
          end
        )

      _ ->
        :ok
    end)

    Logger.info(
      "node:#{node}, #{inspect(length(tables_bk))} RESTAURED tables from file #{inspect(path)}"
    )
  end

  defp filename_with_date(filename) do
    date_str = DateTime.utc_now() |> DateTime.to_string()
    "#{filename}.#{date_str}"
  end
end
