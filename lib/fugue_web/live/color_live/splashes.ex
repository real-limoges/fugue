defmodule FugueWeb.ColorLive.Splashes do
  @moduledoc """
  Function components for each /color section's splash figure. Pure
  Phoenix.Component — no LiveView state. State lives in `FugueWeb.ColorLive`
  and flows in via attrs (protanope toggle, lambda, metamer index, WCS
  language).
  """

  use Phoenix.Component

  alias FugueWeb.ColorLive.ConeMath

  # Protan-metameric pairs for sections 3 + 6. Each {a, b, label} has been
  # verified to collapse to the same color under Machado severity-1.0
  # protanope simulation (delta <= 2 RGB units). Found by stepping along
  # the null vector of the Machado matrix in linear RGB.
  @metamer_pairs [
    {"#da3030", "#006632", "red / green"},
    {"#ff9805", "#26b40e", "saffron"},
    {"#d67d00", "#029603", "deep mustard"},
    {"#da8930", "#00a032", "orange / spring-green"},
    {"#c6740f", "#048b13", "amber"},
    {"#dc8967", "#00a067", "warm tan"},
    {"#da8989", "#00a089", "salmon / sage"},
    {"#da306c", "#00666d", "pink / teal"},
    {"#ca9ed6", "#00afd6", "sky"},
    {"#9073a2", "#007fa2", "steel blue"},
    {"#896581", "#047181", "plum-grey"},
    {"#5e4c6c", "#0b546c", "deep slate"}
  ]

  # Section 6 pins to a single pair from @metamer_pairs (no carousel -- it's
  # the echo of section 3, not a re-cycle). Index into the list above.
  @remainder_pair_index 7

  def metamer_pair_count, do: length(@metamer_pairs)

  # ----- Section 1 hero: iridescent papillae -----
  # Cuttlefish-papillae thickness map driven by a Voronoi field, illuminated
  # by thin-film interference math. Cursor proximity sets the effective
  # viewing angle so the rainbow shifts as the reader hovers. Fragment
  # shader lives in assets/js/hooks/iridescence.js. The canvas is the hook
  # element directly (matches CloudsCanvas convention); phx-update="ignore"
  # keeps LiveView from clobbering it on re-render.

  def iridescence_splash(assigns) do
    ~H"""
    <figure class="space-y-3">
      <canvas
        id="iridescence-canvas"
        phx-hook="IridescenceCanvas"
        phx-update="ignore"
        class="block w-full rounded border border-base-content/10 bg-base-200/30"
        style="aspect-ratio: 5 / 3;"
      >
      </canvas>
    </figure>
    """
  end

  # ----- Spectrum strips (section 1 hero / section 7 closer) -----
  # Public to dodge unused-function warnings while hero_splash is on ice;
  # @compile :nowarn_unused_functions doesn't silence Elixir's own warning.

  @hero_lambda_step 2
  @hero_strips for l <- 380..700//@hero_lambda_step,
                   do: {l, Fugue.Color.Spectrum.hex(l)}

  def hero_splash(assigns) do
    strip_count = div(700 - 380, @hero_lambda_step) + 1

    assigns =
      assigns
      |> assign(:strips, @hero_strips)
      |> assign(:strip_w, 1000.0 / strip_count)

    ~H"""
    <figure class="space-y-3">
      <div class="w-full rounded border border-base-content/10 bg-base-200/30 p-4">
        <svg
          viewBox="0 0 1000 220"
          class="w-full h-auto"
          role="img"
          aria-label="Visible spectrum from 380 to 700 nanometers, rendered as continuous color."
        >
          <g>
            <rect
              :for={{{lambda, hex}, i} <- Enum.with_index(@strips)}
              x={Float.round(i * @strip_w, 2)}
              y="20"
              width={Float.round(@strip_w + 0.5, 2)}
              height="140"
              fill={hex}
            >
              <title>{lambda} nm</title>
            </rect>
          </g>

          <g
            stroke="currentColor"
            stroke-opacity="0.4"
            stroke-width="1"
            font-family="ui-monospace, monospace"
            font-size="11"
            fill="currentColor"
            fill-opacity="0.55"
            text-anchor="middle"
          >
            <line x1="0" y1="160" x2="1000" y2="160" stroke-opacity="0.18" />
            <g :for={l <- [400, 450, 500, 550, 600, 650, 700]}>
              <line x1={(l - 380) / 320 * 1000} y1="160" x2={(l - 380) / 320 * 1000} y2="170" />
              <text x={(l - 380) / 320 * 1000} y="184">{l}</text>
            </g>
            <text x="500" y="206" fill-opacity="0.45" font-size="10">wavelength (nm)</text>
          </g>
        </svg>
      </div>
      <figcaption class="font-mono text-xs uppercase tracking-widest text-base-content/50">
        Light.
      </figcaption>
    </figure>
    """
  end

  def closer_splash(assigns) do
    strip_count = div(700 - 380, @hero_lambda_step) + 1

    assigns =
      assigns
      |> assign(:strips, @hero_strips)
      |> assign(:strip_w, 1000.0 / strip_count)

    ~H"""
    <figure class="space-y-2">
      <div class="w-full rounded border border-base-content/10 bg-base-200/30 p-3">
        <svg
          viewBox="0 0 1000 60"
          class="w-full h-auto"
          role="img"
          aria-label="Spectrum strip from section one."
        >
          <rect
            :for={{{_l, hex}, i} <- Enum.with_index(@strips)}
            x={Float.round(i * @strip_w, 2)}
            y="0"
            width={Float.round(@strip_w + 0.5, 2)}
            height="60"
            fill={hex}
          />
        </svg>
      </div>
    </figure>
    """
  end

  # ----- Section 5a: WCS chip grid -----

  attr :language, :atom, required: true

  def wcs_splash(assigns) do
    h_count = Fugue.Color.WCSMock.hue_count()
    l_count = Fugue.Color.WCSMock.lightness_count()

    chips =
      for l <- 0..(l_count - 1), h <- 0..(h_count - 1) do
        {term, consensus} = Fugue.Color.WCSMock.modal(assigns.language, h, l)

        %{
          h: h,
          l: l,
          base: Fugue.Color.WCSMock.chip_color(h, l),
          term: term,
          term_color: Fugue.Color.WCSMock.term_color(term),
          consensus: consensus
        }
      end

    legend = Fugue.Color.WCSMock.terms(assigns.language)

    assigns =
      assigns
      |> assign(:h_count, h_count)
      |> assign(:l_count, l_count)
      |> assign(:chips, chips)
      |> assign(:legend, legend)

    ~H"""
    <figure class="space-y-3">
      <div class="w-full rounded border border-base-content/10 bg-base-200/30 p-3">
        <div
          class="grid gap-px"
          style={"grid-template-columns: repeat(#{@h_count}, minmax(0, 1fr));"}
        >
          <div
            :for={c <- @chips}
            class="aspect-square relative"
            style={"background: #{c.base};"}
            title={"#{c.term} (consensus #{Float.round(c.consensus, 2)})"}
          >
            <div
              class="absolute inset-0"
              style={"background: #{c.term_color}; opacity: #{Float.round(c.consensus * 0.55, 3)};"}
            >
            </div>
          </div>
        </div>
      </div>

      <div class="flex items-center justify-between gap-4 flex-wrap">
        <ul class="flex flex-wrap gap-x-3 gap-y-1 font-mono text-xs text-base-content/65">
          <li :for={t <- @legend} class="flex items-center gap-1.5">
            <span
              class="inline-block w-3 h-3 rounded-sm"
              style={"background: #{Fugue.Color.WCSMock.term_color(t)};"}
            >
            </span>
            <span>{t}</span>
          </li>
        </ul>

        <button
          type="button"
          phx-click="cycle_wcs_language"
          class="font-mono text-xs uppercase tracking-widest px-3 py-1.5 rounded border border-base-content/20 hover:border-base-content/40 hover:bg-base-200/40 transition-colors whitespace-nowrap"
        >
          {Fugue.Color.WCSMock.language_label(@language)} / next
        </button>
      </div>

      <figcaption class="font-mono text-xs text-base-content/45 leading-relaxed not-italic">
        Each chip painted with the name most speakers gave it. Faded means
        they didn't agree.
      </figcaption>
    </figure>
    """
  end

  # ----- Section 5b: hand-curated language boundary strips -----

  @langs_groups [
    %{
      title: "the whole spectrum in two",
      anchor_hue_start: 400,
      anchor_hue_end: 700,
      rows: [
        %{
          language: "English",
          baseline: true,
          bounds: [
            {0.30, "blue"},
            {0.53, "green"},
            {0.62, "yellow"},
            {0.73, "orange"},
            {1.0, "red"}
          ]
        },
        %{language: "Dani", bounds: [{0.53, "mili"}, {1.0, "mola"}]}
      ]
    },
    %{
      title: "splits of blue",
      anchor_hue_start: 450,
      anchor_hue_end: 510,
      rows: [
        %{language: "English", baseline: true, bounds: [{1.0, "blue"}]},
        %{language: "Russian", bounds: [{0.40, "синий (siniy)"}, {1.0, "голубой (goluboy)"}]},
        %{language: "Mongolian", bounds: [{0.45, "хөх (khökh)"}, {1.0, "цэнхэр (tsenkher)"}]},
        %{language: "Turkish", bounds: [{0.35, "lacivert"}, {1.0, "mavi"}]},
        %{language: "Italian", bounds: [{0.35, "blu"}, {0.70, "azzurro"}, {1.0, "celeste"}]}
      ]
    },
    %{
      title: "splits of red",
      anchor_hue_start: 600,
      anchor_hue_end: 700,
      rows: [
        %{language: "English", baseline: true, bounds: [{1.0, "red"}]},
        %{language: "Hungarian", bounds: [{0.45, "piros"}, {1.0, "vörös"}]},
        %{language: "Czech", bounds: [{0.50, "červený"}, {1.0, "rudý"}]}
      ]
    },
    %{
      title: "where green and blue meet",
      anchor_hue_start: 470,
      anchor_hue_end: 560,
      rows: [
        %{language: "English", baseline: true, bounds: [{0.22, "blue"}, {1.0, "green"}]},
        %{language: "Welsh", bounds: [{0.55, "glas"}, {1.0, "gwyrdd"}]},
        %{language: "Vietnamese", bounds: [{1.0, "xanh"}]},
        %{language: "Japanese", bounds: [{0.55, "青 (ao)"}, {1.0, "緑 (midori)"}]},
        %{language: "Kazakh", bounds: [{0.50, "көк (kök)"}, {1.0, "жасыл (jasyl)"}]},
        %{language: "Navajo", bounds: [{1.0, "dootłʼizh (dootlizh)"}]}
      ]
    },
    %{
      title: "where the lines don't match",
      anchor_hue_start: 510,
      anchor_hue_end: 580,
      rows: [
        %{language: "English", baseline: true, bounds: [{0.64, "green"}, {1.0, "yellow"}]},
        %{language: "Berinmo", bounds: [{0.29, "nol"}, {1.0, "wor"}]}
      ]
    },
    %{
      title: "the warm side",
      anchor_hue_start: 560,
      anchor_hue_end: 700,
      rows: [
        %{
          language: "English",
          baseline: true,
          bounds: [{0.18, "yellow"}, {0.46, "orange"}, {1.0, "red"}]
        },
        %{language: "Himba", bounds: [{0.14, "dumbu"}, {1.0, "serandu"}]}
      ]
    }
  ]

  def langs_splash(assigns) do
    assigns = assign(assigns, :groups, @langs_groups)

    ~H"""
    <figure class="space-y-3">
      <div class="w-full rounded border border-base-content/10 bg-base-200/30 p-4 space-y-7">
        <div :for={group <- @groups} class="space-y-2">
          <div class="flex items-baseline justify-between gap-3">
            <span class="font-mono text-xs uppercase tracking-widest text-base-content/70">
              {group.title}
            </span>
            <span class="font-mono text-xs text-base-content/40 tabular-nums">
              {group.anchor_hue_start}-{group.anchor_hue_end} nm
            </span>
          </div>

          <.hue_strip a={group.anchor_hue_start} b={group.anchor_hue_end} />

          <div class="space-y-1">
            <.partition_row
              :for={row <- group.rows}
              language={row.language}
              bounds={row.bounds}
              baseline={Map.get(row, :baseline, false)}
            />
          </div>
        </div>
      </div>
      <figcaption class="font-mono text-xs text-base-content/45 leading-relaxed not-italic">
        Each group is one spectrum, cut different ways. English rows are
        baselines. Placements are approximate; the splits themselves are real.
      </figcaption>
    </figure>
    """
  end

  attr :a, :integer, required: true
  attr :b, :integer, required: true

  defp hue_strip(assigns) do
    strips =
      for i <- 0..63 do
        t = i / 63
        lambda = assigns.a + (assigns.b - assigns.a) * t
        {t, Fugue.Color.Spectrum.hex(lambda)}
      end

    assigns = assign(assigns, :strips, strips)

    ~H"""
    <div class="grid grid-cols-[5rem_1fr] items-center gap-3">
      <span></span>
      <svg
        viewBox="0 0 1000 28"
        class="w-full h-auto"
        preserveAspectRatio="none"
        role="img"
        aria-label={"hue strip from #{@a} to #{@b} nm"}
      >
        <rect
          :for={{{t, hex}, _i} <- Enum.with_index(@strips)}
          x={Float.round(t * 1000, 2)}
          y="0"
          width="18"
          height="28"
          fill={hex}
        />
      </svg>
    </div>
    """
  end

  attr :language, :string, required: true
  attr :bounds, :list, required: true
  attr :baseline, :boolean, default: false

  defp partition_row(assigns) do
    segments = lang_segments(assigns.bounds)
    ticks = assigns.bounds |> Enum.drop(-1) |> Enum.map(fn {f, _} -> f end)

    assigns =
      assigns
      |> assign(:segments, segments)
      |> assign(:ticks, ticks)

    ~H"""
    <div class="grid grid-cols-[5rem_1fr] items-center gap-3">
      <span class={[
        "font-mono text-xs text-right",
        if(@baseline, do: "text-base-content/45 italic", else: "text-base-content/70")
      ]}>
        {@language}
      </span>
      <div class={[
        "relative h-6 border-y",
        if(@baseline, do: "border-base-content/10", else: "border-base-content/15")
      ]}>
        <div
          :for={tick <- @ticks}
          class={[
            "absolute top-0 bottom-0 w-px",
            if(@baseline, do: "bg-base-content/30", else: "bg-base-content/65")
          ]}
          style={"left: #{tick * 100}%;"}
        >
        </div>
        <span
          :for={seg <- @segments}
          class={[
            "absolute font-mono text-xs",
            if(@baseline, do: "text-base-content/55 italic", else: "text-base-content/85")
          ]}
          style={"left: #{(seg.start + seg.end) / 2 * 100}%; top: 50%; transform: translate(-50%, -50%);"}
        >
          {seg.term}
        </span>
      </div>
    </div>
    """
  end

  defp lang_segments(bounds) do
    {segs, _prev} =
      Enum.map_reduce(bounds, 0.0, fn {frac, term}, prev ->
        {%{start: prev, end: frac, term: term}, frac}
      end)

    segs
  end

  # ----- Section 2: cone curves -----

  attr :protanope, :boolean, required: true
  attr :lambda, :float, required: true

  def cone_splash(assigns) do
    cones =
      if assigns.protanope,
        do: [{:s, "#a78bfa"}, {:m, "#86efac"}],
        else: [{:s, "#a78bfa"}, {:m, "#86efac"}, {:l, "#fbbf24"}]

    cursor_x = ConeMath.cone_x_of(assigns.lambda)

    activations =
      Enum.map(cones, fn {cone, color} ->
        response = Fugue.Color.Cones.response(cone, assigns.lambda - ConeMath.cone_shift(cone))
        %{cone: cone, color: color, response: response, dot_y: ConeMath.cone_y_of(response)}
      end)

    assigns =
      assigns
      |> assign(:cones, cones)
      |> assign(:cursor_x, cursor_x)
      |> assign(:activations, activations)

    ~H"""
    <figure class="space-y-3">
      <div class="w-full rounded border border-base-content/10 bg-base-200/30 p-4">
        <svg
          viewBox="0 0 800 320"
          class="w-full h-auto"
          role="img"
          aria-label={
            if @protanope,
              do: "Two cone curves: M and S. The L curve is absent.",
              else: "Three cone curves: L, M, and S, with L shifted toward M."
          }
        >
          <g stroke="currentColor" stroke-opacity="0.18" stroke-width="1">
            <line x1="60" y1="270" x2="770" y2="270" />
            <line x1="60" y1="30" x2="60" y2="270" />
          </g>

          <g
            font-family="ui-monospace, monospace"
            font-size="11"
            fill="currentColor"
            fill-opacity="0.45"
            text-anchor="middle"
          >
            <text x={ConeMath.cone_x_of(400)} y="288">400</text>
            <text x={ConeMath.cone_x_of(500)} y="288">500</text>
            <text x={ConeMath.cone_x_of(600)} y="288">600</text>
            <text x={ConeMath.cone_x_of(700)} y="288">700</text>
            <text x="400" y="308" font-size="10" fill-opacity="0.55">wavelength (nm)</text>
          </g>

          <g :for={{cone, color} <- @cones}>
            <polyline
              points={ConeMath.cone_curve_points(cone)}
              fill="none"
              stroke={color}
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              opacity="0.92"
            />
            <text
              x={
                ConeMath.cone_x_of(
                  ConeMath.cone_peak(cone) + ConeMath.cone_shift(cone) +
                    ConeMath.cone_label_dx(cone)
                )
              }
              y={ConeMath.cone_y_of(1.0) - 8}
              text-anchor="middle"
              font-family="ui-monospace, monospace"
              font-size="12"
              fill={color}
            >
              μ_{ConeMath.cone_label(cone)}(λ)
            </text>
          </g>

          <line
            x1={@cursor_x}
            y1="30"
            x2={@cursor_x}
            y2="270"
            stroke="currentColor"
            stroke-opacity="0.45"
            stroke-width="1"
            stroke-dasharray="3 3"
          />
          <circle
            :for={a <- @activations}
            cx={@cursor_x}
            cy={a.dot_y}
            r="4"
            fill={a.color}
            stroke="currentColor"
            stroke-opacity="0.4"
            stroke-width="1"
          />
        </svg>
      </div>

      <form phx-change="set_lambda" class="space-y-2">
        <input
          type="range"
          name="lambda"
          min="380"
          max="700"
          step="1"
          value={trunc(@lambda)}
          phx-throttle="30"
          class="w-full accent-base-content/60"
          aria-label="wavelength in nanometers"
        />
        <div class="font-mono text-xs text-base-content/50 flex justify-between">
          <span>380</span>
          <span>λ = {trunc(@lambda)} nm</span>
          <span>700</span>
        </div>
      </form>

      <ul class="font-mono text-xs space-y-1.5">
        <li :for={a <- @activations} class="flex items-center gap-3">
          <span class="w-12 text-base-content/70">μ_{ConeMath.cone_label(a.cone)}</span>
          <span class="flex-1 h-2 rounded bg-base-content/10 overflow-hidden">
            <span
              class="block h-full rounded"
              style={"width: #{Float.round(a.response * 100, 1)}%; background: #{a.color};"}
            >
            </span>
          </span>
          <span class="w-12 text-right text-base-content/70 tabular-nums">
            {Float.round(a.response, 2)}
          </span>
        </li>
      </ul>

      <div class="flex items-center justify-between gap-4">
        <figcaption class="font-mono text-xs uppercase tracking-widest text-base-content/50">
          {if @protanope, do: "Two cones", else: "Three cones, L shifted"}
        </figcaption>
        <button
          type="button"
          phx-click="toggle_protanope"
          aria-pressed={to_string(@protanope)}
          class="font-mono text-xs uppercase tracking-widest px-3 py-1.5 rounded border border-base-content/20 hover:border-base-content/40 hover:bg-base-200/40 transition-colors"
        >
          {if @protanope, do: "show three cones", else: "show two cones"}
        </button>
      </div>
    </figure>
    """
  end

  # ----- Section 4: gamut diagram -----

  def gamut_splash(assigns) do
    cell_size = Fugue.Color.SrgbGamut.step() * 100 * 2.5

    assigns =
      assigns
      |> assign(:locus_points, ConeMath.locus_polyline_points())
      |> assign(:srgb_points, ConeMath.srgb_points())
      |> assign(:p3_points, ConeMath.p3_points())
      |> assign(:rec2020_points, ConeMath.rec2020_points())
      |> assign(:gamut_cells, Fugue.Color.SrgbGamut.cells())
      |> assign(:gamut_cell_size, cell_size)

    ~H"""
    <figure class="space-y-3">
      <div class="w-full rounded border border-base-content/10 bg-base-200/30 p-4">
        <svg
          viewBox="0 0 85 90"
          class="w-full h-auto"
          role="img"
          aria-label="CIE 1931 chromaticity diagram with sRGB, DCI-P3, and Rec. 2020 gamut triangles overlaid on the spectral locus."
        >
          <g stroke="currentColor" stroke-opacity="0.18" stroke-width="0.2" fill="none">
            <line x1="3" y1="85" x2="83" y2="85" />
            <line x1="3" y1="5" x2="3" y2="85" />
          </g>

          <defs>
            <clipPath id="srgb-clip">
              <polygon points={@srgb_points} />
            </clipPath>
          </defs>

          <polygon
            points={@locus_points}
            fill="currentColor"
            fill-opacity="0.05"
            stroke="none"
          />

          <g clip-path="url(#srgb-clip)">
            <rect
              :for={{cx, cy, hex} <- @gamut_cells}
              x={Float.round((cx - Fugue.Color.SrgbGamut.step() / 2) * 100, 3)}
              y={Float.round(85 - (cy + Fugue.Color.SrgbGamut.step() / 2) * 100, 3)}
              width={@gamut_cell_size}
              height={@gamut_cell_size}
              fill={hex}
            />
          </g>

          <polygon
            points={@rec2020_points}
            fill="none"
            stroke="#fbbf24"
            stroke-width="0.5"
            stroke-linejoin="round"
          />
          <polygon
            points={@p3_points}
            fill="none"
            stroke="#86efac"
            stroke-width="0.5"
            stroke-linejoin="round"
            stroke-dasharray="1.2 0.8"
          />
          <polygon
            points={@srgb_points}
            fill="none"
            stroke="#a78bfa"
            stroke-opacity="0.7"
            stroke-width="0.3"
            stroke-linejoin="round"
          />

          <polygon
            points={@locus_points}
            fill="none"
            stroke="currentColor"
            stroke-opacity="0.65"
            stroke-width="0.4"
            stroke-linejoin="round"
          />

          <g
            font-family="ui-monospace, monospace"
            font-size="2.6"
            fill="currentColor"
            fill-opacity="0.7"
            text-anchor="end"
          >
            <text x="83" y="9" fill="#fbbf24">Rec.2020</text>
            <text x="83" y="14" fill="#86efac">DCI-P3</text>
            <text x="83" y="19" fill="#a78bfa">sRGB</text>
          </g>

          <g
            font-family="ui-monospace, monospace"
            font-size="2.0"
            font-weight="bold"
            text-anchor="middle"
            dominant-baseline="middle"
          >
            <text
              x="74.2"
              y="59.2"
              fill="#ef4444"
              style="fill: color(rec2020 1 0 0);"
            >
              X
            </text>
          </g>

          <line
            x1="74.2"
            y1="60.7"
            x2="74.2"
            y2="68"
            stroke="currentColor"
            stroke-opacity="0.4"
            stroke-width="0.2"
          />

          <g
            font-family="ui-monospace, monospace"
            font-size="2.0"
            fill="currentColor"
            fill-opacity="0.8"
            text-anchor="middle"
          >
            <text x="74.2" y="70.5">you can see this.</text>
            <text x="74.2" y="73.5">no screen can.</text>
          </g>
        </svg>
      </div>
      <figcaption class="font-mono text-xs text-base-content/55 leading-relaxed not-italic">
        Filled: your screen. Rings beyond: what fancier ones reach. The
        whole shell: an eye.
      </figcaption>
    </figure>
    """
  end

  # ----- Section 6: remainder (fixed protan-metameric pair) -----

  def remainder_splash(assigns) do
    {a_orig, b_orig, _label} = Enum.at(@metamer_pairs, @remainder_pair_index)
    a = Fugue.Color.Daltonize.protan_hex(a_orig)
    b = Fugue.Color.Daltonize.protan_hex(b_orig)

    assigns =
      assigns
      |> assign(:patch_a, a)
      |> assign(:patch_b, b)

    ~H"""
    <figure class="grid grid-cols-2 gap-3">
      <div
        class="aspect-square rounded"
        style={"background: #{@patch_a}"}
        aria-label="protanope-simulated patch A"
      >
      </div>
      <div
        class="aspect-square rounded"
        style={"background: #{@patch_b}"}
        aria-label="protanope-simulated patch B"
      >
      </div>
    </figure>
    """
  end

  # ----- Section 3: metamer carousel -----

  attr :protanope, :boolean, required: true
  attr :index, :integer, required: true

  def metamer_splash(assigns) do
    n = length(@metamer_pairs)
    {a_orig, b_orig, _label} = Enum.at(@metamer_pairs, assigns.index)

    {a, b} =
      if assigns.protanope do
        {Fugue.Color.Daltonize.protan_hex(a_orig), Fugue.Color.Daltonize.protan_hex(b_orig)}
      else
        {a_orig, b_orig}
      end

    assigns =
      assigns
      |> assign(:patch_a, a)
      |> assign(:patch_b, b)
      |> assign(:source_a, a_orig)
      |> assign(:source_b, b_orig)
      |> assign(:pair_label, "#{assigns.index + 1} / #{n}")

    ~H"""
    <figure class="space-y-3">
      <div class="grid grid-cols-2 gap-2 rounded border border-base-content/10 bg-base-200/30 p-3">
        <div class="space-y-1">
          <div class="font-mono text-[10px] uppercase tracking-widest text-base-content/55 flex items-center gap-1">
            <span
              class="inline-block w-2 h-2 rounded-sm border border-base-content/20"
              style={"background: #{@source_a}"}
            >
            </span>
            {@source_a}
          </div>
          <div
            class="aspect-[3/2] rounded"
            style={"background: #{@patch_a}"}
            aria-label={"metamer patch A (source #{@source_a})"}
          >
          </div>
        </div>
        <div class="space-y-1">
          <div class="font-mono text-[10px] uppercase tracking-widest text-base-content/55 flex items-center gap-1">
            <span
              class="inline-block w-2 h-2 rounded-sm border border-base-content/20"
              style={"background: #{@source_b}"}
            >
            </span>
            {@source_b}
          </div>
          <div
            class="aspect-[3/2] rounded"
            style={"background: #{@patch_b}"}
            aria-label={"metamer patch B (source #{@source_b})"}
          >
          </div>
        </div>
      </div>
      <div class="flex items-center justify-between gap-4">
        <figcaption class="font-mono text-xs uppercase tracking-widest text-base-content/50">
          {if @protanope, do: "One color. To me, always.", else: "Two colors."}
        </figcaption>
        <div class="flex items-center gap-2">
          <button
            type="button"
            phx-click="cycle_metamer"
            phx-value-dir="prev"
            aria-label="previous pair"
            class="font-mono text-sm leading-none px-2 py-1.5 rounded border border-base-content/20 hover:border-base-content/40 hover:bg-base-200/40 transition-colors"
          >
            &lsaquo;
          </button>
          <span class="font-mono text-xs uppercase tracking-widest text-base-content/50 tabular-nums px-2 min-w-[3rem] text-center">
            {@pair_label}
          </span>
          <button
            type="button"
            phx-click="cycle_metamer"
            phx-value-dir="next"
            aria-label="next pair"
            class="font-mono text-sm leading-none px-2 py-1.5 rounded border border-base-content/20 hover:border-base-content/40 hover:bg-base-200/40 transition-colors"
          >
            &rsaquo;
          </button>
          <button
            type="button"
            phx-click="toggle_protanope"
            aria-pressed={to_string(@protanope)}
            class="font-mono text-xs uppercase tracking-widest px-3 py-1.5 rounded border border-base-content/20 hover:border-base-content/40 hover:bg-base-200/40 transition-colors ml-1"
          >
            {if @protanope, do: "show trichromat", else: "show protanope"}
          </button>
        </div>
      </div>
    </figure>
    """
  end
end
