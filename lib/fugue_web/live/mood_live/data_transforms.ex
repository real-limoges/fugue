defmodule FugueWeb.MoodLive.DataTransforms do
  @moduledoc "Pure data transformations for mood analysis: clustering, correlations, calendar days."

  alias FugueWeb.MoodLive.Structs.{AnalysisResult, CalendarDay, GapData}

  @dimensions ~w(sleep anxiety sensitivity outlook speed)
  @cluster_colors ~w(#e44dbc #42c8e6 #6ee64d #e6a542 #a86ee6 #e6e042 #e6425a #42e6b8)

  @dim_labels %{
    "sleep" => {"rested", "restless"},
    "anxiety" => {"anxious", "calm"},
    "sensitivity" => {"sensitive", "grounded"},
    "outlook" => {"optimistic", "guarded"},
    "speed" => {"energetic", "slow"}
  }

  @doc "Returns the canonical list of mood dimensions."
  def dimensions, do: @dimensions

  @doc "Parses raw API response into an AnalysisResult with generated cluster names."
  def parse_analysis(raw, entries) do
    membership = raw["membership"] || []

    clusters =
      (raw["clusters"] || [])
      |> Enum.with_index()
      |> Enum.map(fn {c, i} -> Map.put(c, "id", "cluster_#{i}") end)

    # Map original API names -> ids BEFORE we overwrite names with generated ones
    name_to_id =
      Enum.into(clusters, %{}, fn c -> {c["name"], c["id"]} end)

    clusters = generate_cluster_names(clusters, membership, entries)

    %AnalysisResult{
      clusters: clusters,
      membership: membership,
      cluster_colors: build_cluster_colors(clusters),
      name_to_id: name_to_id,
      fpc: raw["fpc"],
      iterations: raw["iterations"]
    }
  end

  @doc "Builds normalized radar centroids for each cluster."
  def build_centroids(entries, %AnalysisResult{} = analysis) do
    analysis.clusters
    |> weighted_centroids(analysis.membership, entries)
    |> Enum.map(fn {cluster, values} ->
      %{id: cluster["id"], name: cluster["name"], values: values}
    end)
    |> normalize_centroids()
  end

  @doc "Builds calendar day structs spanning the full date range, including gap days."
  def build_calendar_days(entries, %AnalysisResult{} = analysis, gaps) do
    imputed = if gaps, do: gaps.imputed_memberships, else: %{}

    entry_map =
      entries
      |> Enum.with_index()
      |> Enum.into(%{}, fn {entry, idx} ->
        mems = build_memberships(Enum.at(analysis.membership, idx), analysis.clusters)
        {entry["date"], %{dimensions: entry["dimensions"], memberships: mems}}
      end)

    dates = Map.keys(entry_map) ++ Map.keys(imputed)

    case dates do
      [] ->
        []

      _ ->
        min_date = Enum.min(dates)
        max_date = Enum.max(dates)

        Date.range(Date.from_iso8601!(min_date), Date.from_iso8601!(max_date))
        |> Enum.map(fn date ->
          ds = Date.to_iso8601(date)

          case Map.get(entry_map, ds) do
            nil ->
              %CalendarDay{
                date: ds,
                dimensions: nil,
                memberships: Map.get(imputed, ds, %{}),
                is_gap: true
              }

            %{dimensions: dims, memberships: mems} ->
              %CalendarDay{
                date: ds,
                dimensions: dims,
                memberships: mems,
                is_gap: false
              }
          end
        end)
    end
  end

  @doc "Builds Pearson correlation matrix between dimensions."
  def build_correlation_matrix(entries, dimensions) do
    vectors =
      Map.new(dimensions, fn dim ->
        vals =
          entries
          |> Enum.map(fn e -> (e["dimensions"] || %{})[dim] end)
          |> Enum.reject(&is_nil/1)

        {dim, vals}
      end)

    Enum.map(dimensions, fn row_dim ->
      Enum.map(dimensions, fn col_dim ->
        pearson(vectors[row_dim] || [], vectors[col_dim] || [])
      end)
    end)
  end

  @doc "Builds membership map from a raw membership row and cluster list."
  def build_memberships(row, clusters) when is_list(row) do
    clusters
    |> Enum.with_index()
    |> Enum.into(%{}, fn {c, i} -> {c["id"], Enum.at(row, i, 0)} end)
  end

  def build_memberships(_, _), do: %{}

  @doc "Remaps gap data keys from API names to internal cluster IDs."
  def remap_gap_keys(nil, _mapping), do: nil

  def remap_gap_keys(%GapData{} = gaps, mapping) do
    %GapData{
      transitions:
        Enum.map(gaps.transitions, fn t ->
          t
          |> Map.update("before", %{}, &remap_keys(&1, mapping))
          |> Map.update("after", %{}, &remap_keys(&1, mapping))
        end),
      length_distribution: gaps.length_distribution,
      imputed_memberships:
        Map.new(gaps.imputed_memberships, fn {date, mems} ->
          {date, remap_keys(mems, mapping)}
        end)
    }
  end

  @doc "Assigns colors from the synthwave palette to each cluster."
  def build_cluster_colors(clusters) do
    clusters
    |> Enum.with_index()
    |> Enum.into(%{}, fn {c, i} ->
      {c["id"], Enum.at(@cluster_colors, rem(i, length(@cluster_colors)))}
    end)
  end

  @doc "Builds contiguous time segments where the dominant cluster stays the same."
  def build_segments([]), do: []

  def build_segments([first | rest]) do
    {segments, current} =
      Enum.reduce(
        rest,
        {[], %{start: first.date, end_date: first.date, cluster: first.cluster}},
        fn day, {segs, cur} ->
          if day.cluster == cur.cluster do
            {segs, %{cur | end_date: day.date}}
          else
            {segs ++ [cur], %{start: day.date, end_date: day.date, cluster: day.cluster}}
          end
        end
      )

    segments ++ [current]
  end

  @doc "Builds a detail map for a single day, including neighbors."
  def build_day_detail(date, assigns) do
    %{entries: entries, analysis: analysis} = assigns

    entry_idx =
      Enum.find_index(entries, fn e -> e["date"] == date end)

    case entry_idx do
      nil ->
        nil

      idx ->
        entry = Enum.at(entries, idx)
        dims = entry["dimensions"] || %{}
        row = Enum.at(analysis.membership, idx, [])

        memberships =
          analysis.clusters
          |> Enum.with_index()
          |> Enum.map(fn {c, i} ->
            %{id: c["id"], name: c["name"], weight: Enum.at(row, i, 0)}
          end)
          |> Enum.sort_by(& &1.weight, :desc)

        dominant = List.first(memberships)

        prev = if idx > 0, do: neighbor_summary(idx - 1, entries, analysis), else: nil

        next =
          if idx < length(entries) - 1,
            do: neighbor_summary(idx + 1, entries, analysis),
            else: nil

        %{
          date: date,
          dimensions: dims,
          memberships: memberships,
          dominant: dominant,
          prev: prev,
          next: next,
          cluster_colors: analysis.cluster_colors
        }
    end
  end

  @doc "Computes summary statistics for the narrative header."
  def narrative_stats(assigns) do
    entries = assigns.entries
    analysis = assigns.analysis
    transitions = assigns.mood_transitions
    gaps = assigns.gaps

    date_range =
      case entries do
        [] ->
          nil

        _ ->
          dates = Enum.map(entries, & &1["date"])
          {Enum.min(dates), Enum.max(dates)}
      end

    dominant_counts =
      entries
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {_entry, idx}, acc ->
        row = Enum.at(analysis.membership, idx, [])

        dominant =
          analysis.clusters
          |> Enum.with_index()
          |> Enum.max_by(fn {_c, i} -> Enum.at(row, i, 0) end, fn -> {nil, 0} end)
          |> elem(0)

        if dominant, do: Map.update(acc, dominant["id"], 1, &(&1 + 1)), else: acc
      end)

    most_common =
      case Enum.max_by(dominant_counts, fn {_k, v} -> v end, fn -> nil end) do
        {id, count} ->
          name = Enum.find(analysis.clusters, fn c -> c["id"] == id end)
          %{id: id, name: name && name["name"], days: count}

        nil ->
          nil
      end

    gap_count = if gaps, do: length(gaps.transitions), else: 0

    %{
      entry_count: length(entries),
      date_range: date_range,
      cluster_count: length(analysis.clusters),
      transition_count: length(transitions),
      most_common: most_common,
      gap_count: gap_count
    }
  end

  # -- Private helpers --

  defp weighted_centroids(clusters, membership, entries) do
    Enum.map(clusters, fn cluster ->
      cluster_idx = String.replace(cluster["id"], "cluster_", "") |> String.to_integer()

      {weighted_sums, total_weight} =
        entries
        |> Enum.with_index()
        |> Enum.reduce({%{}, 0.0}, fn {entry, idx}, {sums, tw} ->
          row = Enum.at(membership, idx, [])
          weight = Enum.at(row, cluster_idx, 0.0)
          dims = entry["dimensions"] || %{}

          new_sums =
            Enum.reduce(@dimensions, sums, fn dim, acc ->
              val = dims[dim] || 0
              Map.update(acc, dim, weight * val, &(&1 + weight * val))
            end)

          {new_sums, tw + weight}
        end)

      values =
        if total_weight > 0,
          do: Map.new(@dimensions, fn d -> {d, (weighted_sums[d] || 0) / total_weight} end),
          else: Map.new(@dimensions, fn d -> {d, 0} end)

      {cluster, values}
    end)
  end

  defp generate_cluster_names(clusters, membership, entries) do
    raw_centroids = weighted_centroids(clusters, membership, entries)

    global_means =
      Map.new(@dimensions, fn dim ->
        vals = Enum.map(raw_centroids, fn {_, v} -> v[dim] end)
        {dim, Enum.sum(vals) / max(length(vals), 1)}
      end)

    global_stds =
      Map.new(@dimensions, fn dim ->
        mean = global_means[dim]
        vals = Enum.map(raw_centroids, fn {_, v} -> v[dim] end)

        variance =
          Enum.sum(Enum.map(vals, fn v -> (v - mean) * (v - mean) end)) / max(length(vals), 1)

        {dim, :math.sqrt(variance)}
      end)

    Enum.map(raw_centroids, fn {cluster, values} ->
      scored =
        @dimensions
        |> Enum.map(fn dim ->
          std = global_stds[dim]
          z = if std > 0.001, do: (values[dim] - global_means[dim]) / std, else: 0
          {dim, z}
        end)
        |> Enum.sort_by(fn {_, z} -> abs(z) end, :desc)

      name = build_name_from_scores(scored)
      Map.put(cluster, "name", name)
    end)
  end

  defp build_name_from_scores(scored) do
    top =
      scored
      |> Enum.take(2)
      |> Enum.filter(fn {_, z} -> abs(z) > 0.2 end)
      |> Enum.map(fn {dim, z} ->
        {high, low} = Map.get(@dim_labels, dim, {dim, dim})
        if z > 0, do: high, else: low
      end)

    case top do
      [a, b] -> "#{String.capitalize(a)} & #{b}"
      [a] -> String.capitalize(a)
      [] -> "Balanced"
    end
  end

  defp normalize_centroids(centroids) do
    ranges =
      Enum.reduce(centroids, %{}, fn c, acc ->
        Enum.reduce(c.values, acc, fn {dim, val}, a ->
          a
          |> Map.update(dim, {val, val}, fn {mn, mx} -> {min(mn, val), max(mx, val)} end)
        end)
      end)

    Enum.map(centroids, fn c ->
      normed =
        Map.new(c.values, fn {dim, val} ->
          {mn, mx} = Map.get(ranges, dim, {0, 1})
          range = mx - mn

          {dim,
           if range > 0 do
             # Floor at 0.15 so the lowest centroid isn't invisible
             0.15 + 0.85 * ((val - mn) / range)
           else
             0.5
           end}
        end)

      %{c | values: normed}
    end)
  end

  defp neighbor_summary(idx, entries, analysis) do
    entry = Enum.at(entries, idx)
    row = Enum.at(analysis.membership, idx, [])

    dominant =
      analysis.clusters
      |> Enum.with_index()
      |> Enum.max_by(fn {_c, i} -> Enum.at(row, i, 0) end, fn -> {nil, 0} end)
      |> elem(0)

    %{
      date: entry["date"],
      dimensions: entry["dimensions"] || %{},
      dominant_id: dominant && dominant["id"],
      dominant_name: dominant && dominant["name"]
    }
  end

  defp pearson(xs, ys) when length(xs) < 2 or length(ys) < 2, do: 0.0

  defp pearson(xs, ys) do
    n = min(length(xs), length(ys))
    xs = Enum.take(xs, n)
    ys = Enum.take(ys, n)
    mx = Enum.sum(xs) / n
    my = Enum.sum(ys) / n

    {num, dx, dy} =
      Enum.zip(xs, ys)
      |> Enum.reduce({0.0, 0.0, 0.0}, fn {x, y}, {num, dx, dy} ->
        xd = x - mx
        yd = y - my
        {num + xd * yd, dx + xd * xd, dy + yd * yd}
      end)

    denom = :math.sqrt(dx) * :math.sqrt(dy)
    if denom == 0, do: 0.0, else: Float.round(num / denom, 4)
  end

  defp remap_keys(map, mapping) when is_map(map) do
    Map.new(map, fn {k, v} -> {Map.get(mapping, k, k), v} end)
  end

  defp remap_keys(other, _mapping), do: other
end
