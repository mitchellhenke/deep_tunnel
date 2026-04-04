Mix.install([
  {:req, "~> 0.5"},
  {:lazy_html, "~> 0.1"},
  {:nimble_csv, "~> 1.3"}
])

url = "https://www.mmsd.com/about-us/milwaukee-rain-facility-information"

%{status: 200, body: body} = Req.get!(url)

document = LazyHTML.from_document(body)

cards = LazyHTML.query(document, "div.tunnel-info")

# Card 0: Deep Tunnel (Inline Storage System)
# Card 1: Northwest Side Deep Tunnel
# Card 2: South Shore WRF
# Card 3: Jones Island WRF

parse_number_from_text = fn text ->
  case Regex.run(~r/(\d+)\s*million/, text) do
    [_, num] -> num
    _ -> ""
  end
end

parse_values = fn card ->
  paragraphs = LazyHTML.query(card, "p")

  current =
    card
    |> LazyHTML.query("input[name='current-storage']")
    |> Enum.at(0)
    |> case do
      nil ->
        nil

      el ->
        case LazyHTML.attribute(el, "value") do
          val when val in [nil, ""] -> nil
          val -> val
        end
    end

  current =
    current ||
      paragraphs
      |> Enum.find(fn p ->
        String.contains?(LazyHTML.text(p), "CURRENT STORAGE") or
          String.contains?(LazyHTML.text(p), "CURRENTLY TREATING")
      end)
      |> case do
        nil -> ""
        p -> parse_number_from_text.(LazyHTML.text(p))
      end

  max =
    card
    |> LazyHTML.query("input[name='max-capacity']")
    |> Enum.at(0)
    |> case do
      nil ->
        nil

      el ->
        case LazyHTML.attribute(el, "value") do
          val when val in [nil, ""] -> nil
          val -> val
        end
    end

  max =
    max ||
      paragraphs
      |> Enum.find(fn p -> String.contains?(LazyHTML.text(p), "MAX CAPACITY") end)
      |> case do
        nil -> ""
        p -> parse_number_from_text.(LazyHTML.text(p))
      end

  {current, max}
end

parse_timestamp = fn card ->
  card
  |> LazyHTML.query("em")
  |> Enum.at(0)
  |> case do
    nil -> ""
    el -> LazyHTML.text(el) |> String.trim()
  end
end

deep_tunnel = Enum.at(cards, 0)
nw_deep_tunnel = Enum.at(cards, 1)
south_shore = Enum.at(cards, 2)
jones_island = Enum.at(cards, 3)

{dt_current, dt_max} = parse_values.(deep_tunnel)
dt_timestamp = parse_timestamp.(deep_tunnel)

{nw_current, nw_max} = parse_values.(nw_deep_tunnel)
nw_timestamp = parse_timestamp.(nw_deep_tunnel)

{ss_current, ss_max} = parse_values.(south_shore)
ss_timestamp = parse_timestamp.(south_shore)

{ji_current, ji_max} = parse_values.(jones_island)
ji_timestamp = parse_timestamp.(jones_island)

csv_path = "data.csv"

header =
  "scraped_at,deep_tunnel_timestamp,deep_tunnel_current,deep_tunnel_max,nw_deep_tunnel_timestamp,nw_deep_tunnel_current,nw_deep_tunnel_max,south_shore_timestamp,south_shore_current,south_shore_max,jones_island_timestamp,jones_island_current,jones_island_max"

current_timestamps = [dt_timestamp, nw_timestamp, ss_timestamp, ji_timestamp]

last_timestamps =
  if File.exists?(csv_path) do
    rows =
      csv_path
      |> File.read!()
      |> NimbleCSV.RFC4180.parse_string(skip_headers: true)

    case List.last(rows) do
      nil ->
        nil

      row ->
        [Enum.at(row, 1), Enum.at(row, 4), Enum.at(row, 7), Enum.at(row, 10)]
    end
  else
    nil
  end

if last_timestamps == current_timestamps do
  IO.puts("No update — all timestamps unchanged")
else
  unless File.exists?(csv_path) do
    File.write!(csv_path, header <> "\n")
  end

  scraped_at = DateTime.utc_now() |> DateTime.to_iso8601()

  row =
    NimbleCSV.RFC4180.dump_to_iodata([
      [
        scraped_at,
        dt_timestamp,
        dt_current,
        dt_max,
        nw_timestamp,
        nw_current,
        nw_max,
        ss_timestamp,
        ss_current,
        ss_max,
        ji_timestamp,
        ji_current,
        ji_max
      ]
    ])

  File.write!(csv_path, row, [:append])

  IO.puts("Scraped and appended to #{csv_path}")
  IO.puts("Deep Tunnel: #{dt_current}/#{dt_max} MG (#{dt_timestamp})")
  IO.puts("NW Deep Tunnel: #{nw_current}/#{nw_max} MG (#{nw_timestamp})")
  IO.puts("South Shore: #{ss_current}/#{ss_max} MGD (#{ss_timestamp})")
  IO.puts("Jones Island: #{ji_current}/#{ji_max} MGD (#{ji_timestamp})")
end
