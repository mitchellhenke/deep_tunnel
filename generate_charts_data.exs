csv_path = "data.csv"

unless File.exists?(csv_path) do
  IO.puts("No data.csv found")
  System.halt(1)
end

lines =
  csv_path
  |> File.read!()
  |> String.trim()
  |> String.split("\n")

[_header | rows] = lines

one_week_ago = DateTime.utc_now() |> DateTime.add(-7, :day)

parse_csv_line = fn line ->
  {_, fields} =
    Enum.reduce(String.graphemes(line), {false, [""]}, fn char, {in_quotes, [current | rest]} ->
      cond do
        char == "\"" -> {!in_quotes, [current | rest]}
        char == "," and not in_quotes -> {false, ["", current | rest]}
        true -> {in_quotes, [current <> char | rest]}
      end
    end)

  Enum.reverse(fields)
end

to_int = fn str ->
  case Integer.parse(str || "") do
    {n, _} -> n
    :error -> nil
  end
end

readings =
  rows
  |> Enum.map(fn row ->
    fields = parse_csv_line.(row)

    scraped_at = Enum.at(fields, 0, nil)

    %{
      scraped_at: scraped_at,
      deep_tunnel: %{
        current: to_int.(Enum.at(fields, 2, nil)),
        max: to_int.(Enum.at(fields, 3, nil))
      },
      nw_deep_tunnel: %{
        current: to_int.(Enum.at(fields, 5, nil)),
        max: to_int.(Enum.at(fields, 6, nil))
      },
      south_shore: %{
        current: to_int.(Enum.at(fields, 8, nil)),
        max: to_int.(Enum.at(fields, 9, nil))
      },
      jones_island: %{
        current: to_int.(Enum.at(fields, 11, nil)),
        max: to_int.(Enum.at(fields, 12, nil))
      }
    }
  end)
  |> Enum.filter(fn %{scraped_at: ts} ->
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _} -> DateTime.compare(dt, one_week_ago) != :lt
      _ -> false
    end
  end)

json = JSON.encode!(readings)
File.write!("data/readings.json", json)
IO.puts("Generated data/readings.json with #{length(readings)} readings")
