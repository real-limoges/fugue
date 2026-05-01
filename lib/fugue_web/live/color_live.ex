defmodule FugueWeb.ColorLive do
  use FugueWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Color")
     |> assign(
       :meta_description,
       "Color is a transaction between light, eye, screen, and word."
     )
     |> assign(:protanope, false)
     |> assign(:lambda, 540.0)}
  end

  def handle_event("toggle_protanope", _params, socket) do
    {:noreply, assign(socket, :protanope, !socket.assigns.protanope)}
  end

  def handle_event("set_lambda", %{"lambda" => v}, socket) do
    {:noreply, assign(socket, :lambda, String.to_integer(v) * 1.0)}
  end

  def render(assigns) do
    ~H"""
    <article class="px-4 py-8 max-w-3xl mx-auto text-base-content/90 space-y-24">
      <header class="space-y-4">
        <p class="font-mono text-xs tracking-widest uppercase text-primary/70">
          A chapter
        </p>
        <h1 class="text-4xl sm:text-5xl font-semibold tracking-tight text-white">
          Color is a transaction.
        </h1>
        <p class="font-mono text-xs text-base-content/40">
          [stub: framing tagline only — full intro deferred]
        </p>
      </header>

      <.section number="1" id="prism" title="The prism">
        <:splash label="hero splash TBD (prism parked — see docs)" aspect="aspect-[16/9]" />
        <p class="text-lg leading-relaxed">This is where color begins.</p>
        <.stub_note>
          Hero splash deferred. Prism was the original plan but feels like worn
          ground; revisit later or replace with a different opener.
          No author yet, no qualifications. The reader is allowed the easy story.
        </.stub_note>
      </.section>

      <.section number="2" id="eye" title="The eye's guesses">
        <.cone_splash protanope={@protanope} lambda={@lambda} />

        <p class="leading-relaxed">
          The eye has three cones, each tuned a little differently. Light comes in,
          three numbers come out.
        </p>

        <p class="text-lg leading-relaxed">
          Cones are membership functions. Color is the result.
        </p>

        <p class="leading-relaxed">
          Most people make three guesses. I make two.
        </p>

        <p class="leading-relaxed text-base-content/70">
          Three isn't fundamental. Some people have four. Mantis shrimp have sixteen.
        </p>

        <.stub_note>
          [draft prose — fuzzy-frame sentence and personal beat are starter copy from the plan,
          rework as needed. Wavelength slider deferred (cones.wasm vendored; ship/skip TBD).
          Toggle is local to section 2 today; will be lifted to a shared assign once sections 3 and 6 hook in.]
        </.stub_note>
      </.section>

      <.section number="3" id="metamerism" title="Two colors, same color">
        <.metamer_splash protanope={@protanope} />
        <.stub_note>
          [v1: two patches that match for protanope (no L) but differ for a normal
          trichromat. Toggle is shared with section 2 — once a reader is in
          protanope mode, the patches collapse. v2 should add the anomalous-trichromat
          midpoint (damaged L cone) and hover-revealed spectral bars; design plan's
          "matches for trichromat / differs for protanope" direction is mathematically
          impossible (a trichromat metamer is automatically a dichromat metamer), so
          we use the achievable inverse direction.]
        </.stub_note>
      </.section>

      <.section number="4" id="gamut" title="Where the screen can't reach">
        <.gamut_splash />

        <p class="leading-relaxed">
          The eye gives the screen three numbers; the screen answers with fewer. The
          diagram itself is in trichromat coordinates — a map of what the screen can't
          reach, made by the screen.
        </p>

        <p class="leading-relaxed">
          Each layer drops something on the way through; none of it gets put back.
        </p>

        <.stub_note>
          [v1 throw-up. Mock prose. Cut candidate if chapter runs long; if cut,
          fold the "each layer compresses" beat into section 3.]
        </.stub_note>
      </.section>

      <.section number="5" id="language" title="Language carves it up">
        <p class="leading-relaxed">
          Cones partition wavelength; language partitions cones. Different languages
          partition differently, and where they do, the line's real to whoever drew it.
        </p>

        <.placeholder_splash label="WCS chip grids (Berinmo + English baseline + 2-3 more) — Timbre data pending" />

        <p class="leading-relaxed">
          Berinmo cuts the green-yellow region in a place English doesn't. Berinmo
          speakers tell colors across that line apart faster than colors on the same
          side. The line's doing work.
        </p>

        <.placeholder_splash label="Russian / Hungarian / Welsh illustrations — secondary literature" />

        <p class="leading-relaxed">
          Russian splits blue: siniy, goluboy. Hungarian splits red. Welsh has glas,
          which covers green and bits of blue and gray. None of these are translation
          problems; they're different partitions of the same continuum.
        </p>

        <p class="leading-relaxed">
          Some languages skip abstract color words. Yélî Dnye, on Rossel Island,
          describes a color by what it's like — the night sky, ripe pandanus, burned
          wood. The category "color word" is a habit.
        </p>

        <p class="leading-relaxed">
          I learned "red" before I understood I wasn't seeing it the way the word
          implied. Some of those lines are real to their speakers and invisible to me.
        </p>

        <.stub_note>
          [v1 throw-up. Mock prose, all lines drafty. Splash 5a (WCS chip grids) blocked
          on Timbre repo bootstrapping; splash 5b (Russian / Hungarian / Welsh) is
          hand-curated — design pass not started. Decide later: drop one personal beat
          if both crowd; ship 5b as a separate splash or fold into 5a.]
        </.stub_note>
      </.section>

      <.section
        number="6"
        id="remainder"
        title={Phoenix.HTML.raw(~s|What I <span class="text-red-500">X</span> show you|)}
      >
        <p class="leading-relaxed">
          Five sections so far. Light, eye, screen, word — chains that can be pinned
          down.
        </p>

        <p class="leading-relaxed">This isn't that.</p>

        <.remainder_splash />

        <p class="leading-relaxed">
          The light is measurable. So are the cones, the screen's primaries, the
          categories language draws. One thing isn't — what it's like, on the inside.
        </p>

        <p class="leading-relaxed">
          There's a thought experiment about a scientist who learns everything about
          red and then sees it. This is the inverse.
        </p>

        <.stub_note>
          [v1 throw-up. Hardest writing problem in the chapter — budget more drafting
          passes than the other six combined. Chain-is-public / having-is-not is the
          load-bearing beat; Mary's Room inversion lands AFTER. No Nagel, no Jackson
          by name. Splash here reuses section 3's metamer pair locked to protanope sim;
          the failure caption is the argument.]
        </.stub_note>
      </.section>

      <.section number="7" id="closer" title="After">
        <p class="leading-relaxed">
          Light, eye, screen, word. Four parties, all of them in the open.
        </p>

        <p class="text-lg leading-relaxed">
          Color is a transaction.
        </p>

        <.stub_note>
          [v1 throw-up. The fifth party — the having — is deliberately left off the
          list. Splash here originally reused the section 1 prism; that's parked, so
          §7 is text-only for now. May want a tiny callback image or just keep it
          short and silent.]
        </.stub_note>
      </.section>
    </article>
    """
  end

  attr :number, :string, required: true
  attr :id, :string, required: true
  attr :title, :any, required: true

  slot :splash do
    attr :label, :string, required: true
    attr :aspect, :string, required: true
  end

  slot :inner_block, required: true

  defp section(assigns) do
    ~H"""
    <section id={@id} class="space-y-6">
      <div class="flex items-baseline gap-4 border-b border-base-content/10 pb-2">
        <span class="font-mono text-xs text-primary/60 tracking-widest">{@number}</span>
        <h2 class="text-2xl font-semibold text-white tracking-tight">{@title}</h2>
      </div>

      <div
        :for={s <- @splash}
        class={[
          "w-full rounded border-2 border-dashed border-base-content/20 bg-base-200/30 flex items-center justify-center",
          s.aspect
        ]}
      >
        <span class="font-mono text-xs text-base-content/40 tracking-wider px-4 text-center">
          {s.label}
        </span>
      </div>

      <div class="prose prose-invert max-w-none space-y-4">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  slot :inner_block, required: true

  defp stub_note(assigns) do
    ~H"""
    <p class="font-mono text-xs text-base-content/40 border-l-2 border-base-content/20 pl-3 italic">
      [stub] {render_slot(@inner_block)}
    </p>
    """
  end

  attr :label, :string, required: true
  attr :aspect, :string, default: "aspect-[16/9]"

  defp placeholder_splash(assigns) do
    ~H"""
    <div class={[
      "w-full rounded border-2 border-dashed border-base-content/20 bg-base-200/30 flex items-center justify-center",
      @aspect
    ]}>
      <span class="font-mono text-xs text-base-content/40 tracking-wider px-4 text-center">
        {@label}
      </span>
    </div>
    """
  end

  attr :protanope, :boolean, required: true
  attr :lambda, :float, required: true

  defp cone_splash(assigns) do
    cones =
      if assigns.protanope,
        do: [{:s, "#a78bfa"}, {:m, "#86efac"}],
        else: [{:s, "#a78bfa"}, {:m, "#86efac"}, {:l, "#fbbf24"}]

    cursor_x = cone_x_of(assigns.lambda)

    activations =
      Enum.map(cones, fn {cone, color} ->
        response = Fugue.Color.Cones.response(cone, assigns.lambda - cone_shift(cone))
        %{cone: cone, color: color, response: response, dot_y: cone_y_of(response)}
      end)

    assigns =
      assigns
      |> assign(:cones, cones)
      |> assign(:cursor_x, cursor_x)
      |> assign(:activations, activations)

    ~H"""
    <figure class="space-y-3">
      <div class="w-full rounded border border-base-content/10 bg-base-200/30 p-4">
        <svg viewBox="0 0 800 320" class="w-full h-auto" role="img"
             aria-label={if @protanope, do: "Two cone curves: M and S. The L curve is absent.", else: "Three cone curves: L, M, and S, with L shifted toward M."}>
          <g stroke="currentColor" stroke-opacity="0.18" stroke-width="1">
            <line x1="60" y1="270" x2="770" y2="270" />
            <line x1="60" y1="30"  x2="60"  y2="270" />
          </g>

          <g font-family="ui-monospace, monospace" font-size="11" fill="currentColor" fill-opacity="0.45" text-anchor="middle">
            <text x={cone_x_of(400)} y="288">400</text>
            <text x={cone_x_of(500)} y="288">500</text>
            <text x={cone_x_of(600)} y="288">600</text>
            <text x={cone_x_of(700)} y="288">700</text>
            <text x="400" y="308" font-size="10" fill-opacity="0.55">wavelength (nm)</text>
          </g>

          <g :for={{cone, color} <- @cones}>
            <polyline
              points={cone_curve_points(cone)}
              fill="none"
              stroke={color}
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              opacity="0.92"
            />
            <text
              x={cone_x_of(cone_peak(cone) + cone_shift(cone))}
              y={cone_y_of(1.0) - 8}
              text-anchor="middle"
              font-family="ui-monospace, monospace"
              font-size="12"
              fill={color}
            >μ_{cone_label(cone)}(λ)</text>
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
          <span class="w-12 text-base-content/70">μ_{cone_label(a.cone)}</span>
          <span class="flex-1 h-2 rounded bg-base-content/10 overflow-hidden">
            <span
              class="block h-full rounded"
              style={"width: #{Float.round(a.response * 100, 1)}%; background: #{a.color};"}
            ></span>
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

  # CIE 1931 2-deg spectral locus (x, y) at 10 nm spacing, 380-700 nm.
  # Source: standard CIE tables.
  @spectral_locus [
    {380, 0.1741, 0.0050}, {390, 0.1738, 0.0049}, {400, 0.1733, 0.0048},
    {410, 0.1726, 0.0048}, {420, 0.1714, 0.0051}, {430, 0.1689, 0.0069},
    {440, 0.1644, 0.0109}, {450, 0.1566, 0.0177}, {460, 0.1440, 0.0297},
    {470, 0.1241, 0.0578}, {480, 0.0913, 0.1327}, {490, 0.0454, 0.2950},
    {500, 0.0082, 0.5384}, {510, 0.0139, 0.7502}, {520, 0.0743, 0.8338},
    {530, 0.1547, 0.8059}, {540, 0.2296, 0.7543}, {550, 0.3016, 0.6923},
    {560, 0.3731, 0.6245}, {570, 0.4441, 0.5547}, {580, 0.5125, 0.4866},
    {590, 0.5752, 0.4242}, {600, 0.6270, 0.3725}, {610, 0.6658, 0.3340},
    {620, 0.6915, 0.3083}, {630, 0.7079, 0.2920}, {640, 0.7190, 0.2809},
    {650, 0.7260, 0.2740}, {660, 0.7300, 0.2700}, {670, 0.7320, 0.2680},
    {680, 0.7334, 0.2666}, {690, 0.7344, 0.2656}, {700, 0.7347, 0.2653}
  ]

  # Display gamut primaries in CIE xy. White points (D65 ≈ 0.3127, 0.3290) ignored
  # for now; we are drawing the closed triangle of the primaries only.
  @gamut_srgb     [{0.640, 0.330}, {0.300, 0.600}, {0.150, 0.060}]
  @gamut_dci_p3   [{0.680, 0.320}, {0.265, 0.690}, {0.150, 0.060}]
  @gamut_rec2020  [{0.708, 0.292}, {0.170, 0.797}, {0.131, 0.046}]

  # Chromaticity (x, y) -> SVG (x, y) inside an 80 x 90 viewBox, with y flipped
  # so chromaticity-y grows upward. 100x scale factor -> chromaticity 0.5
  # lands at 50 in SVG units.
  @gamut_view_h 90
  defp chrom_x(x), do: x * 100
  defp chrom_y(y), do: @gamut_view_h - y * 100 - 5

  defp locus_polyline_points do
    Enum.map_join(@spectral_locus, " ", fn {_lambda, x, y} ->
      "#{Float.round(chrom_x(x), 2)},#{Float.round(chrom_y(y), 2)}"
    end)
  end

  defp gamut_polygon_points(points) do
    Enum.map_join(points, " ", fn {x, y} ->
      "#{Float.round(chrom_x(x), 2)},#{Float.round(chrom_y(y), 2)}"
    end)
  end

  defp gamut_splash(assigns) do
    assigns =
      assigns
      |> assign(:locus_points, locus_polyline_points())
      |> assign(:srgb_points, gamut_polygon_points(@gamut_srgb))
      |> assign(:p3_points, gamut_polygon_points(@gamut_dci_p3))
      |> assign(:rec2020_points, gamut_polygon_points(@gamut_rec2020))

    ~H"""
    <figure class="space-y-3">
      <div class="w-full rounded border border-base-content/10 bg-base-200/30 p-4">
        <svg viewBox="0 0 85 90" class="w-full h-auto" role="img"
             aria-label="CIE 1931 chromaticity diagram with sRGB, DCI-P3, and Rec. 2020 gamut triangles overlaid on the spectral locus.">
          <g stroke="currentColor" stroke-opacity="0.18" stroke-width="0.2" fill="none">
            <line x1="3" y1="85" x2="83" y2="85" />
            <line x1="3" y1="5"  x2="3"  y2="85" />
          </g>

          <polygon
            points={@locus_points}
            fill="currentColor"
            fill-opacity="0.06"
            stroke="currentColor"
            stroke-opacity="0.6"
            stroke-width="0.4"
            stroke-linejoin="round"
          />

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
            stroke-width="0.5"
            stroke-linejoin="round"
            stroke-dasharray="0.5 0.5"
          />

          <g font-family="ui-monospace, monospace" font-size="2.6" fill="currentColor" fill-opacity="0.7">
            <text x="74" y="64" fill="#fbbf24">Rec.2020</text>
            <text x="68" y="68" fill="#86efac">DCI-P3</text>
            <text x="62" y="72" fill="#a78bfa">sRGB</text>
          </g>

          <g font-family="ui-monospace, monospace" font-size="2.2" fill="currentColor" fill-opacity="0.45">
            <text x="3" y="89">x</text>
            <text x="0.5" y="6">y</text>
            <text x="44" y="3">spectral locus</text>
          </g>
        </svg>
      </div>
      <figcaption class="font-mono text-xs uppercase tracking-widest text-base-content/50">
        You can see this. No screen can.
      </figcaption>
    </figure>
    """
  end

  # Hand-picked metamer pair: two trichromat-distinguishable colors that lie
  # close to the same protan confusion line, so they collapse to (almost) the
  # same color under Machado severity-1.0 protanope simulation.
  @metamer_a "#c83232"
  @metamer_b "#7d712b"

  defp remainder_splash(assigns) do
    a = Fugue.Color.Daltonize.protan_hex(@metamer_a)
    b = Fugue.Color.Daltonize.protan_hex(@metamer_b)

    assigns =
      assigns
      |> assign(:patch_a, a)
      |> assign(:patch_b, b)

    ~H"""
    <figure class="space-y-3">
      <div class="grid grid-cols-2 gap-2 rounded border border-base-content/10 bg-base-200/30 p-3">
        <div
          class="aspect-[3/2] rounded"
          style={"background: #{@patch_a}"}
          aria-label="protanope-simulated patch A"
        >
        </div>
        <div
          class="aspect-[3/2] rounded"
          style={"background: #{@patch_b}"}
          aria-label="protanope-simulated patch B"
        >
        </div>
      </div>
      <figcaption class="font-mono text-xs text-base-content/50 leading-relaxed not-italic">
        This is a trichromat's translation, computed in trichromat color space,
        rendered on a trichromat-calibrated screen. It is not what I see. What I
        see is not on this page and could not be.
      </figcaption>
    </figure>
    """
  end

  attr :protanope, :boolean, required: true

  defp metamer_splash(assigns) do
    {a, b} =
      if assigns.protanope do
        {Fugue.Color.Daltonize.protan_hex(@metamer_a),
         Fugue.Color.Daltonize.protan_hex(@metamer_b)}
      else
        {@metamer_a, @metamer_b}
      end

    assigns =
      assigns
      |> assign(:patch_a, a)
      |> assign(:patch_b, b)

    ~H"""
    <figure class="space-y-3">
      <div class="grid grid-cols-2 gap-2 rounded border border-base-content/10 bg-base-200/30 p-3">
        <div
          class="aspect-[3/2] rounded"
          style={"background: #{@patch_a}"}
          aria-label="metamer patch A"
        >
        </div>
        <div
          class="aspect-[3/2] rounded"
          style={"background: #{@patch_b}"}
          aria-label="metamer patch B"
        >
        </div>
      </div>
      <figcaption class="font-mono text-xs uppercase tracking-widest text-base-content/50">
        {if @protanope, do: "One color. To me, always.", else: "Two colors."}
      </figcaption>
    </figure>
    """
  end

  # Plot uses Stockman & Sharpe 2000 2-deg cone fundamentals (peak-normalized)
  # via Fugue.Color.Cones. Visible-spectrum window is 380-700 nm; the S cone
  # in S&S starts at 390 nm so values below that clamp.
  @lambda_min 380.0
  @lambda_max 700.0
  @plot_x_left 60
  @plot_x_right 770
  @plot_y_top 30
  @plot_y_bottom 270

  # Approximate λ_max of each fundamental, for label positioning.
  @cone_peak %{l: 565.0, m: 533.0, s: 442.0}

  # When the L cone is present in the splash, it is shown shifted toward M
  # (anomalous trichromacy / protanomaly). The chapter never shows the
  # canonical "normal trichromat" baseline on purpose.
  @cone_shift %{l: -15.0, m: 0.0, s: 0.0}

  defp cone_x_of(lambda) do
    span = @plot_x_right - @plot_x_left
    @plot_x_left + (lambda - @lambda_min) / (@lambda_max - @lambda_min) * span
  end

  defp cone_y_of(response) do
    span = @plot_y_bottom - @plot_y_top
    @plot_y_bottom - response * span
  end

  defp cone_peak(cone), do: @cone_peak[cone]
  defp cone_shift(cone), do: @cone_shift[cone]
  defp cone_label(:l), do: "L"
  defp cone_label(:m), do: "M"
  defp cone_label(:s), do: "S"

  defp cone_curve_points(cone) do
    shift = @cone_shift[cone]

    @lambda_min
    |> Stream.iterate(&(&1 + 2.0))
    |> Stream.take_while(&(&1 <= @lambda_max))
    |> Enum.map_join(" ", fn lambda ->
      x = Float.round(cone_x_of(lambda), 2)
      y = Float.round(cone_y_of(Fugue.Color.Cones.response(cone, lambda - shift)), 2)
      "#{x},#{y}"
    end)
  end
end
