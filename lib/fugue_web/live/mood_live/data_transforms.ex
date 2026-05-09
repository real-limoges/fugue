defmodule FugueWeb.MoodLive.DataTransforms do
  @moduledoc "Pure data transformations for mood analysis: clustering, distributions, calendar days."

  alias FugueWeb.MoodLive.Structs.{AnalysisResult, CalendarDay, GapData}

  @dimensions ~w(sleep anxiety sensitivity outlook speed)
  @cluster_colors ~w(#e44dbc #42c8e6 #6ee64d #e6a542 #a86ee6 #e6e042 #e6425a #42e6b8)

  # Minimum consecutive days a new dominant cluster must persist to count as a
  # real state transition. Shorter runs are absorbed into the surrounding state
  # so the timeline reflects lived shifts, not argmax noise on near-tied days.
  @min_run_length 5

  @dim_labels %{
    "sleep" => {"rested", "restless"},
    "anxiety" => {"anxious", "calm"},
    "sensitivity" => {"sensitive", "grounded"},
    "outlook" => {"optimistic", "guarded"},
    "speed" => {"energetic", "slow"}
  }

  @doc "Returns the canonical list of mood dimensions."
  def dimensions, do: @dimensions

  @doc """
  Builds per-dimension histograms for the membership function editor.
  `bounds_by_dim` maps each dimension name to `{lo, hi}`. Returns a map of
  `dim => [%{x0, x1, n}]` with `bin_count` equal-width bins, counts
  normalized to the densest bin so the visual peak is always 1.0.
  """
  def build_histograms(entries, bounds_by_dim, bin_count \\ 20) do
    Map.new(@dimensions, fn dim ->
      {lo, hi} = Map.get(bounds_by_dim, dim, {0.0, 10.0})

      values =
        entries
        |> Enum.map(fn e -> (e["dimensions"] || %{})[dim] end)
        |> Enum.reject(&is_nil/1)

      {dim, bin_values(values, lo, hi, bin_count)}
    end)
  end

  defp bin_values([], lo, hi, bin_count) do
    width = (hi - lo) / bin_count

    Enum.map(0..(bin_count - 1), fn i ->
      %{x0: lo + i * width, x1: lo + (i + 1) * width, n: 0.0}
    end)
  end

  defp bin_values(values, lo, hi, bin_count) do
    width = (hi - lo) / bin_count

    counts =
      Enum.reduce(values, :array.new(bin_count, default: 0), fn v, acc ->
        idx =
          cond do
            v <= lo -> 0
            v >= hi -> bin_count - 1
            true -> min(trunc((v - lo) / width), bin_count - 1)
          end

        :array.set(idx, :array.get(idx, acc) + 1, acc)
      end)

    raw = Enum.map(0..(bin_count - 1), fn i -> :array.get(i, counts) end)
    peak = Enum.max(raw, fn -> 1 end)
    peak = if peak == 0, do: 1, else: peak

    raw
    |> Enum.with_index()
    |> Enum.map(fn {count, i} ->
      %{x0: lo + i * width, x1: lo + (i + 1) * width, n: count / peak}
    end)
  end

  @doc "Parses raw API response into an AnalysisResult with generated cluster names."
  def parse_analysis(raw, entries) do
    raw_membership = raw["membership"] || []

    clusters =
      (raw["clusters"] || [])
      |> Enum.with_index()
      |> Enum.map(fn {c, i} -> Map.put(c, "id", "cluster_#{i}") end)

    # Map original API names -> ids BEFORE we overwrite names with generated ones
    name_to_id =
      Enum.into(clusters, %{}, fn c -> {c["name"], c["id"]} end)

    # Store membership as tuple-of-tuples for O(1) indexed access
    membership = raw_membership |> Enum.map(&List.to_tuple/1) |> List.to_tuple()

    # Compute centroids once -- used for naming and later for radar charts
    raw_centroids = weighted_centroids(clusters, membership, entries)
    clusters = generate_cluster_names_from_centroids(clusters, raw_centroids)

    %AnalysisResult{
      clusters: clusters,
      membership: membership,
      cluster_colors: build_cluster_colors(clusters),
      name_to_id: name_to_id,
      cluster_names: Enum.into(clusters, %{}, fn c -> {c["id"], c["name"]} end),
      cluster_ids: Enum.map(clusters, & &1["id"]),
      raw_centroids: raw_centroids,
      fpc: raw["fpc"],
      iterations: raw["iterations"]
    }
  end

  @doc "Builds normalized radar centroids for each cluster from cached raw centroids."
  def build_centroids(%AnalysisResult{} = analysis) do
    analysis.raw_centroids
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
        mems = build_memberships(elem(analysis.membership, idx), analysis.clusters)
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

  @doc "Builds membership map from a raw membership row (tuple or list) and cluster list."
  def build_memberships(row, clusters) when is_tuple(row) do
    size = tuple_size(row)

    clusters
    |> Enum.with_index()
    |> Enum.into(%{}, fn {c, i} ->
      {c["id"], if(i < size, do: elem(row, i), else: 0)}
    end)
  end

  def build_memberships(row, clusters) when is_list(row) do
    build_memberships(List.to_tuple(row), clusters)
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

  @doc "Returns chronological list of %{date, cluster} for each entry's dominant cluster."
  def daily_dominants(entries, %AnalysisResult{} = analysis) do
    entries
    |> Enum.with_index()
    |> Enum.map(fn {entry, idx} ->
      row = elem(analysis.membership, idx)

      dominant =
        analysis.clusters
        |> Enum.with_index()
        |> Enum.max_by(fn {_c, i} -> elem(row, i) end, fn -> {nil, 0} end)
        |> elem(0)

      %{date: entry["date"], cluster: dominant && dominant["id"]}
    end)
    |> Enum.filter(& &1.cluster)
  end

  @doc """
  Smooths a daily dominant-cluster sequence by holding the current state until
  a new cluster persists for at least `min_length` consecutive days.
  """
  def smooth_runs(daily, min_length \\ @min_run_length)
  def smooth_runs([], _min_length), do: []
  def smooth_runs(daily, min_length) when min_length <= 1, do: daily

  def smooth_runs([first | _] = daily, min_length) do
    do_smooth_runs(daily, first.cluster, min_length, [])
  end

  defp do_smooth_runs([], _state, _min, acc), do: Enum.reverse(acc)

  defp do_smooth_runs([day | rest] = all, state, min_length, acc) do
    cond do
      day.cluster == state ->
        do_smooth_runs(rest, state, min_length, [%{day | cluster: state} | acc])

      forward_streak(all, day.cluster) >= min_length ->
        do_smooth_runs(rest, day.cluster, min_length, [day | acc])

      true ->
        do_smooth_runs(rest, state, min_length, [%{day | cluster: state} | acc])
    end
  end

  defp forward_streak(days, cluster) do
    Enum.reduce_while(days, 0, fn day, count ->
      if day.cluster == cluster, do: {:cont, count + 1}, else: {:halt, count}
    end)
  end

  @doc "The minimum run length used by `smooth_runs/1`."
  def min_run_length, do: @min_run_length

  @doc """
  Projects the entries' five raw dimensions to 2D via PCA and returns
  chronologically-ordered points with their smoothed dominant cluster. The
  hero trajectory chart at the top of the page draws a line through these
  in order -- four years of mood as a single scribble in a 2D space the data
  discovered for itself.
  """
  def build_trajectory(entries, smoothed_daily) do
    matrix =
      Enum.map(entries, fn e ->
        dims = e["dimensions"] || %{}
        Enum.map(@dimensions, fn dim -> (dims[dim] || 0) * 1.0 end)
      end)

    dim_count = length(@dimensions)
    n = length(matrix)

    if n < 2 do
      []
    else
      means =
        Enum.map(0..(dim_count - 1), fn i ->
          Enum.sum(Enum.map(matrix, fn row -> Enum.at(row, i) end)) / n
        end)

      centered =
        Enum.map(matrix, fn row ->
          row |> Enum.zip(means) |> Enum.map(fn {v, m} -> v - m end)
        end)

      cov = covariance_matrix(centered, dim_count)
      {pc1, lam1} = power_iteration(cov, dim_count)
      cov2 = deflate_matrix(cov, pc1, lam1, dim_count)
      {pc2, _} = power_iteration(cov2, dim_count)

      raw =
        Enum.map(centered, fn row ->
          {dot(row, pc1), dot(row, pc2)}
        end)

      {first_x, _} = List.first(raw)
      {last_x, _} = List.last(raw)
      flip_x = if first_x > last_x, do: -1.0, else: 1.0

      cluster_by_date = Map.new(smoothed_daily, fn d -> {d.date, d.cluster} end)

      raw
      |> Enum.zip(entries)
      |> Enum.map(fn {{x, y}, entry} ->
        %{
          x: x * flip_x,
          y: y,
          date: entry["date"],
          cluster: Map.get(cluster_by_date, entry["date"])
        }
      end)
    end
  end

  defp covariance_matrix(centered, d) do
    n = length(centered)
    divisor = max(n - 1, 1)

    for i <- 0..(d - 1) do
      for j <- 0..(d - 1) do
        sum =
          Enum.reduce(centered, 0.0, fn row, acc ->
            acc + Enum.at(row, i) * Enum.at(row, j)
          end)

        sum / divisor
      end
    end
  end

  defp power_iteration(mat, d, iters \\ 200) do
    init = List.duplicate(0.0, d) |> List.replace_at(0, 1.0)

    Enum.reduce(1..iters, {init, 0.0}, fn _, {v, _} ->
      mv = mat_vec(mat, v)
      norm = vec_norm(mv)

      if norm < 1.0e-12 do
        {v, 0.0}
      else
        {Enum.map(mv, fn x -> x / norm end), norm}
      end
    end)
  end

  defp deflate_matrix(mat, v, lambda, d) do
    for i <- 0..(d - 1) do
      row = Enum.at(mat, i)
      vi = Enum.at(v, i)

      for j <- 0..(d - 1) do
        Enum.at(row, j) - lambda * vi * Enum.at(v, j)
      end
    end
  end

  defp mat_vec(mat, v) do
    Enum.map(mat, fn row ->
      row |> Enum.zip(v) |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)
    end)
  end

  defp vec_norm(v) do
    :math.sqrt(Enum.reduce(v, 0.0, fn x, acc -> acc + x * x end))
  end

  defp dot(v1, v2) do
    v1 |> Enum.zip(v2) |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)
  end

  @doc """
  Builds monthly mood flowers: averaged dimensions per month plus the modal
  smoothed cluster for that month. Values are normalized 0.2–1.0 against the
  per-dimension range across all months so each flower's spoke length reflects
  that month's value relative to the user's full history.
  """
  def build_mood_flowers(entries, smoothed_daily) do
    cluster_mode_by_month =
      smoothed_daily
      |> Enum.group_by(fn d -> String.slice(d.date, 0, 7) end)
      |> Map.new(fn {month, days} ->
        modal =
          days
          |> Enum.frequencies_by(& &1.cluster)
          |> Enum.max_by(fn {_k, v} -> v end, fn -> {nil, 0} end)
          |> elem(0)

        {month, modal}
      end)

    monthly =
      entries
      |> Enum.group_by(fn e -> String.slice(e["date"], 0, 7) end)
      |> Enum.map(fn {month, month_entries} ->
        raw =
          Map.new(@dimensions, fn dim ->
            vals =
              month_entries
              |> Enum.map(fn e -> (e["dimensions"] || %{})[dim] end)
              |> Enum.reject(&is_nil/1)

            mean = if vals == [], do: 0.0, else: Enum.sum(vals) / length(vals)
            {dim, mean}
          end)

        %{
          month: month,
          raw: raw,
          count: length(month_entries),
          cluster: Map.get(cluster_mode_by_month, month)
        }
      end)
      |> Enum.sort_by(& &1.month)

    ranges =
      Map.new(@dimensions, fn dim ->
        vals = Enum.map(monthly, & &1.raw[dim])
        {dim, {Enum.min(vals, fn -> 0.0 end), Enum.max(vals, fn -> 1.0 end)}}
      end)

    Enum.map(monthly, fn m ->
      values =
        Map.new(@dimensions, fn dim ->
          {mn, mx} = ranges[dim]
          range = mx - mn

          v =
            if range > 0,
              do: 0.2 + 0.8 * ((m.raw[dim] - mn) / range),
              else: 0.5

          {dim, v}
        end)

      Map.put(m, :values, values)
    end)
  end

  @doc "Aggregates cluster dominance by month-of-year across all years for seasonality analysis."
  def build_seasonality(smoothed_daily) do
    by_month =
      smoothed_daily
      |> Enum.group_by(fn d ->
        d.date |> String.slice(5, 2) |> String.to_integer()
      end)

    Enum.map(1..12, fn month ->
      days = Map.get(by_month, month, [])
      total = length(days)
      counts = Enum.frequencies_by(days, & &1.cluster)
      %{month: month, counts: counts, total: total}
    end)
  end

  @doc "Builds a histogram of max-membership values for the ambiguity visualization."
  def build_ambiguity_histogram(entries, %AnalysisResult{} = analysis) do
    max_memberships =
      entries
      |> Enum.with_index()
      |> Enum.map(fn {_entry, idx} ->
        row = elem(analysis.membership, idx)
        row |> Tuple.to_list() |> Enum.max(fn -> 0 end)
      end)

    lo = 0.3
    hi = 1.0
    bin_count = 20
    width = (hi - lo) / bin_count

    counts =
      Enum.reduce(max_memberships, :array.new(bin_count, default: 0), fn v, acc ->
        idx = min(max(trunc((v - lo) / width), 0), bin_count - 1)
        :array.set(idx, :array.get(idx, acc) + 1, acc)
      end)

    Enum.map(0..(bin_count - 1), fn i ->
      %{
        x0: Float.round(lo + i * width, 3),
        x1: Float.round(lo + (i + 1) * width, 3),
        count: :array.get(i, counts)
      }
    end)
  end

  @doc "Computes per-dimension rolling averages for long-term drift analysis."
  def build_drift(entries, window \\ 90) do
    sorted = Enum.sort_by(entries, & &1["date"])
    n = length(sorted)
    half = div(window, 2)

    Enum.map(@dimensions, fn dim ->
      values =
        Enum.map(sorted, fn e ->
          v = (e["dimensions"] || %{})[dim]
          if is_nil(v), do: 0.0, else: v * 1.0
        end)

      series =
        sorted
        |> Enum.with_index()
        |> Enum.map(fn {entry, i} ->
          win_lo = max(0, i - half)
          win_hi = min(n - 1, i + half)
          window_vals = Enum.slice(values, win_lo, win_hi - win_lo + 1)
          mean = Enum.sum(window_vals) / length(window_vals)
          %{date: entry["date"], value: Float.round(mean, 2)}
        end)

      %{dimension: dim, series: series}
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
            {[cur | segs], %{start: day.date, end_date: day.date, cluster: day.cluster}}
          end
        end
      )

    Enum.reverse([current | segments])
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
        row = elem(analysis.membership, idx)

        memberships =
          analysis.clusters
          |> Enum.with_index()
          |> Enum.map(fn {c, i} ->
            %{id: c["id"], name: c["name"], weight: elem(row, i)}
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
  def narrative_stats(entries, analysis, smoothed_daily, mood_transitions, gaps) do
    transitions = mood_transitions

    date_range =
      case entries do
        [] ->
          nil

        _ ->
          dates = Enum.map(entries, & &1["date"])
          {Enum.min(dates), Enum.max(dates)}
      end

    daily = smoothed_daily

    initial = %{counts: %{}, prev: nil, run: 0, longest: {nil, 0}, first: nil, last: nil}

    summary =
      Enum.reduce(daily, initial, fn %{cluster: id}, acc ->
        counts = Map.update(acc.counts, id, 1, &(&1 + 1))
        run = if acc.prev == id, do: acc.run + 1, else: 1
        longest = if run > elem(acc.longest, 1), do: {id, run}, else: acc.longest

        %{
          counts: counts,
          prev: id,
          run: run,
          longest: longest,
          first: acc.first || id,
          last: id
        }
      end)

    most_common =
      case Enum.max_by(summary.counts, fn {_k, v} -> v end, fn -> nil end) do
        {id, count} -> lookup_cluster(id, analysis.clusters, days: count)
        nil -> nil
      end

    longest_run =
      case summary.longest do
        {nil, _} -> nil
        {id, days} -> lookup_cluster(id, analysis.clusters, days: days)
      end

    biggest_flow =
      case transitions do
        [] ->
          nil

        _ ->
          {{from_id, to_id}, count} =
            transitions
            |> Enum.reduce(%{}, fn t, acc -> Map.update(acc, {t.from, t.to}, 1, &(&1 + 1)) end)
            |> Enum.max_by(fn {_pair, c} -> c end)

          %{
            from: lookup_cluster(from_id, analysis.clusters),
            to: lookup_cluster(to_id, analysis.clusters),
            count: count
          }
      end

    gap_count = if gaps, do: length(gaps.transitions), else: 0

    %{
      entry_count: length(entries),
      date_range: date_range,
      cluster_count: length(analysis.clusters),
      transition_count: length(transitions),
      most_common: most_common,
      gap_count: gap_count,
      longest_run: longest_run,
      first_state: lookup_cluster(summary.first, analysis.clusters),
      last_state: lookup_cluster(summary.last, analysis.clusters),
      biggest_flow: biggest_flow,
      ambiguity: ambiguity_summary(entries, analysis)
    }
  end

  defp lookup_cluster(id, clusters, opts \\ [])
  defp lookup_cluster(nil, _clusters, _opts), do: nil

  defp lookup_cluster(id, clusters, opts) do
    case Enum.find(clusters, fn c -> c["id"] == id end) do
      nil -> nil
      c -> Enum.into(opts, %{id: id, name: c["name"]})
    end
  end

  # -- Private helpers --

  defp ambiguity_summary(entries, analysis, threshold \\ 0.45) do
    count =
      entries
      |> Enum.with_index()
      |> Enum.count(fn {_entry, idx} ->
        row = elem(analysis.membership, idx)
        row |> Tuple.to_list() |> Enum.max(fn -> 0 end) < threshold
      end)

    total = length(entries)

    %{
      count: count,
      pct: if(total > 0, do: round(count / total * 100), else: 0),
      threshold: threshold
    }
  end

  defp weighted_centroids(clusters, membership, entries) do
    Enum.map(clusters, fn cluster ->
      cluster_idx = String.replace(cluster["id"], "cluster_", "") |> String.to_integer()

      {weighted_sums, total_weight} =
        entries
        |> Enum.with_index()
        |> Enum.reduce({%{}, 0.0}, fn {entry, idx}, {sums, tw} ->
          row = elem(membership, idx)
          weight = elem(row, cluster_idx)
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

  defp generate_cluster_names_from_centroids(_clusters, raw_centroids) do
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
    row = elem(analysis.membership, idx)

    dominant =
      analysis.clusters
      |> Enum.with_index()
      |> Enum.max_by(fn {_c, i} -> elem(row, i) end, fn -> {nil, 0} end)
      |> elem(0)

    %{
      date: entry["date"],
      dimensions: entry["dimensions"] || %{},
      dominant_id: dominant && dominant["id"],
      dominant_name: dominant && dominant["name"]
    }
  end

  defp remap_keys(map, mapping) when is_map(map) do
    Map.new(map, fn {k, v} -> {Map.get(mapping, k, k), v} end)
  end

  defp remap_keys(other, _mapping), do: other
end
