defmodule GeoRedi.Constants do
  defmacro __using__(_) do
    quote do
      @clean_addr_after_ms GeoRedi.Constants.clean_addr_after_ms()
    end
  end

  def clean_addr_after_ms() do
    Application.get_env(:georedi, :clean_addr_after_ms) ||
      :timer.hours(24 * 10)
  end
end
