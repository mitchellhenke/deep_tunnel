Mix.install([{:nimble_csv, "~> 1.3"}])

csv_path = "data.csv"

unless File.exists?(csv_path) do
  IO.puts("No data.csv found")
  System.halt(1)
end

one_week_ago = DateTime.utc_now() |> DateTime.add(-7, :day)

to_int = fn str ->
  case Integer.parse(str || "") do
    {n, _} -> n
    :error -> nil
  end
end

to_float = fn str ->
  case Float.parse(str || "") do
    {n, _} -> n
    :error -> nil
  end
end

within_last_week? = fn %{scraped_at: ts} ->
  case DateTime.from_iso8601(ts) do
    {:ok, dt, _} -> DateTime.compare(dt, one_week_ago) != :lt
    _ -> false
  end
end

rows =
  csv_path
  |> File.read!()
  |> NimbleCSV.RFC4180.parse_string(skip_headers: true)

readings =
  rows
  |> Enum.map(fn row ->
    %{
      scraped_at: Enum.at(row, 0),
      deep_tunnel: %{
        current: to_int.(Enum.at(row, 2)),
        max: to_int.(Enum.at(row, 3))
      },
      nw_deep_tunnel: %{
        current: to_int.(Enum.at(row, 5)),
        max: to_int.(Enum.at(row, 6))
      },
      south_shore: %{
        current: to_int.(Enum.at(row, 8)),
        max: to_int.(Enum.at(row, 9))
      },
      jones_island: %{
        current: to_int.(Enum.at(row, 11)),
        max: to_int.(Enum.at(row, 12))
      }
    }
  end)
  |> Enum.filter(within_last_week?)

json = JSON.encode!(readings)
File.write!("data/readings.json", json)
IO.puts("Generated data/readings.json with #{length(readings)} readings")

mccarty_csv_path = "mccarty.csv"

mccarty_readings =
  if File.exists?(mccarty_csv_path) do
    mccarty_csv_path
    |> File.read!()
    |> NimbleCSV.RFC4180.parse_string(skip_headers: true)
    |> Enum.map(fn row ->
      %{
        scraped_at: Enum.at(row, 0),
        mccarty: %{
          current: to_float.(Enum.at(row, 3)),
          max: 100
        },
        mccarty_gauge_height: %{
          current: to_float.(Enum.at(row, 2))
        }
      }
    end)
    |> Enum.filter(within_last_week?)
  else
    []
  end

File.write!("data/mccarty.json", JSON.encode!(mccarty_readings))
IO.puts("Generated data/mccarty.json with #{length(mccarty_readings)} readings")
