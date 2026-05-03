defmodule FugueWeb.ColorLive do
  use FugueWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Color")
     |> assign(
       :meta_description,
       "A chapter about color, written by someone who only sees most of it."
     )
     |> assign(:protanope, false)
     |> assign(:lambda, 540.0)
     |> assign(:wcs_language, :english)}
  end

  def handle_event("toggle_protanope", _params, socket) do
    {:noreply, assign(socket, :protanope, !socket.assigns.protanope)}
  end

  def handle_event("set_lambda", %{"lambda" => v}, socket) do
    {:noreply, assign(socket, :lambda, String.to_integer(v) * 1.0)}
  end

  def handle_event("cycle_wcs_language", _params, socket) do
    langs = Fugue.Color.WCSMock.languages()
    current = socket.assigns.wcs_language
    next = Enum.at(langs, rem(Enum.find_index(langs, &(&1 == current)) + 1, length(langs)))
    {:noreply, assign(socket, :wcs_language, next)}
  end

  def render(assigns) do
    ~H"""
    <article class="px-4 py-8 max-w-3xl mx-auto">
      <header class="mb-16">
        <h1 class="text-3xl font-bold tracking-tight text-base-content">
          Color.
        </h1>
      </header>

      <.section number="1" id="prism" title="The prism">
        <p class="text-sm text-base-content/65 leading-relaxed">
          I'm colorblind. Two cones; the standard issue is three. I mix
          up my socks. I can't play Lite Brite. Avocado ripeness is a
          matter of faith.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          What follows is the tour.
        </p>

        <.placecard label="hero splash — TBD" />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Light, sorted by wavelength. A narrow window the eye accepts;
          longer than this is heat, shorter than this is the kind of
          light that gives you cancer. The range in between counts as
          visible because we're the ones counting.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Bees see ultraviolet. Snakes see infrared. We get the strip in
          the middle. Most of what's flying around the room right now
          isn't on the chart; the chart is whatever your eyes happen to
          listen to.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Easy story. Six sections of ways it isn't.
        </p>
      </.section>

      <.section number="2" id="eye" title="The eye's guesses">
        <.cone_splash protanope={@protanope} lambda={@lambda} />

        <p class="text-sm text-base-content/65 leading-relaxed">
          The eye has three cones. Each one's a sensor that gets excited
          about a different range of wavelengths. Light comes in, three
          numbers come out, and that is everything your brain ever has
          to work with.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Three numbers can't tell you what's actually there. The world
          has thousands of distinguishable wavelengths and your retina
          crushes them down to a triple. The triple is your color.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Cones are membership functions. Color is the result.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          The curves overlap on purpose. A wavelength near the seam
          between two cones triggers both, partly; the brain reads the
          ratio and calls it something. Yellow is a ratio. Pink is a
          ratio. So is the green you're sure of, and the one you're not.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Drag the slider above. The dots tell you how loud each cone is
          at that wavelength. The brain never sees the wavelength
          itself; it sees the loudness.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Most people make three guesses. I make two.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          I'm missing the L cone — the long one, the cone responsible for
          red being a different flavor than green. Without it, my brain
          has two channels arguing with each other and the argument
          always lands in roughly the same place. Christmas trees look
          fine from across the room. Up close, the ornaments and the
          needles agree about the color in a way they're not supposed
          to.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Three isn't fundamental either. Some women have four cones —
          there are studies, those people exist, and they apparently see
          differences in beige paint the rest of us can't. Mantis shrimp
          have sixteen and presumably think the rest of us are barely
          seeing. Bees have three, but their middle cone is in the
          ultraviolet, and flowers have patterns on them we don't know
          are there. Snakes have a separate organ entirely for infrared,
          which is to say snakes can see warm.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Three is a number that comes out of one branch of evolution
          deciding three was good enough. The number isn't about color.
          The number is about us.
        </p>
      </.section>

      <.section number="3" id="metamerism" title="Two colors, same color">
        <p class="text-sm text-base-content/65 leading-relaxed">
          Two patches. They look like two colors. Underneath, the spectra
          disagree wildly — different physical light, almost no shared
          wavelengths. The eye averages each spectrum down to three cone
          numbers; the cones produce different ratios; the brain reports
          two colors.
        </p>

        <.metamer_splash protanope={@protanope} />

        <p class="text-sm text-base-content/65 leading-relaxed">
          This is a magic trick the eye does to itself. There's nothing
          fancy in the math; the trick is just that two completely
          different physical things can hit your three sensors the same
          way. The cones can't tell, so the brain doesn't know there
          was anything to tell.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Your screen depends on this. Every color it shows you is a
          fake. The yellow on this page isn't yellow light — it's red
          and green pixels next to each other in a ratio the eye
          averages into yellow. There is no actual yellow involved. The
          eye never notices.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          It's also why clothes look one color in the store and a
          different one at home. The lights in the store and the lights
          in your kitchen are different spectra hitting the same shirt;
          the cones run different averages over different inputs; the
          answer changes even though the shirt didn't. (Buy clothes
          outdoors.)
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Toggle the protanope view in the cone splash above. The
          patches were two colors; now they're one color. The patches
          haven't moved. My cones run the average; the average lands
          in the same place for both. To a trichromat: two clearly
          different patches. To me: one patch, twice.
        </p>
      </.section>

      <.section number="4" id="gamut" title="Where the screen can't reach">
        <.gamut_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          The filled triangle is your screen — every color it knows how
          to mix. The rings around it are colors only fancier screens
          can mix. The whole horseshoe is what an eye can have. The
          screen reaches in and grabs a triangle.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Three primaries means a triangle. The screen has a red pixel,
          a green pixel, and a blue pixel; everything it shows is a
          weighted mix. Anything outside the triangle is a color a real
          eye can have but the screen can't manufacture from those
          three.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          sRGB is what most monitors do. DCI-P3 is what new phones and
          recent Apple laptops do. Rec.2020 is what high-end TV
          manufacturers gesture at and almost nobody owns. The fancier
          the screen, the bigger the triangle — but it's always a
          triangle, always inside the eye's full shape, always missing
          the edges.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          The X is at a real wavelength of light, a deep spectral red
          around 700 nanometers. You can see it. A sunset is partly
          made of it. No screen in your life is going to render it
          accurately. The X is rendered with a wide-gamut color request:
          on a wide-gamut display it might look slightly more saturated
          than the surrounding sRGB; on a normal display it gets
          clamped to the closest available red. Either way, what you're
          seeing is the closest the screen could come.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          The diagram itself is trichromat. The map of what your screen
          can't reach was drawn so your screen could draw it. The
          chicken-and-egg here is on purpose; it's the same chicken and
          the same egg the rest of the chapter is about.
        </p>
      </.section>

      <.section number="5" id="language" title="Language carves it up">
        <p class="text-sm text-base-content/65 leading-relaxed">
          Cones partition wavelength; language partitions cones.
          Different languages partition differently, and where they do,
          the line's real to whoever drew it.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          How many color words a language needs is also up to the
          language. English has eleven basic ones — red, orange, yellow,
          green, blue, purple, pink, brown, black, white, grey. Some
          languages have only two basic terms: one for the warm half of
          the spectrum, one for the cool. Both languages work fine; both
          speakers see the same wavelengths; each thinks its own
          partition is the obvious one.
        </p>

        <.wcs_splash language={@wcs_language} />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Each chip is colored by the term most speakers used; the
          opacity is how often they agreed. Faded squares are chips the
          speakers argued about. The arguments are also data.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Berinmo cuts the green-yellow region in a place English
          doesn't. Berinmo speakers tell colors across that line apart
          faster than colors on the same side. English speakers do the
          same trick across the green-blue line. The line in your
          language did some work in your brain. The chip on the chart
          didn't change; the speaker did.
        </p>

        <.langs_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Russian splits blue: синий, голубой. Mongolian splits it on a
          different line: хөх, the deep blue of winter ice, against
          цэнхэр, summer sky. Hungarian splits red. Vietnamese xanh
          covers green and blue at once; Japanese 青 (ao) did the same
          until 緑 (midori) carved off a piece a thousand years ago;
          Kazakh көк still covers both, with жасыл a newer green
          settling in. None of these are translation problems. They're
          different partitions of the same continuous thing.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Across hundreds of languages, basic color terms emerge in a
          roughly predictable order. A three-term language always uses
          black, white, and red. Add a fourth and you get green or
          yellow. Add a fifth and you get the other. Blue shows up late,
          possibly because blue is genuinely uncommon in nature outside
          the sky.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Some languages skip abstract color words altogether. Yélî
          Dnye, on Rossel Island, describes a color by what it's like —
          the night sky, ripe pandanus, burned wood, water at dusk. The
          comparison is doing the work an abstract color word would,
          and arguably doing it better; "burned wood" tells you more
          than "brown" if you've ever seen burned wood. The category
          "color word" is a habit.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          And new color words are still being made. Crayola named
          Macaroni and Cheese, Razzmatazz, Outer Space. Pantone named
          Living Coral Color of the Year for 2019. Categories are
          getting invented as we speak; they take when enough people
          use them and don't when not enough do. The chart of basic
          terms above isn't done.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          I learned "red" before I understood I wasn't seeing whatever
          the word pointed at. The word still works fine — I can buy
          red sweaters, mostly, on the second try. Some of those lines
          on the chart above are real to their speakers and invisible
          to me. I'm trusting the chart.
        </p>
      </.section>

      <.section number="6" id="remainder" title="What I can't show you">
        <p class="text-sm text-base-content/65 leading-relaxed">
          Five sections, four parties: light, eye, screen, word. Each
          one with a number against it.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">This is the part that doesn't.</p>

        <.remainder_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Look at the patches above. To a trichromat: two patches in
          two slightly different shades. To me, looking at the same
          patches: nothing in particular. (To me, this is a paragraph
          about two grey patches.) The simulation is a trichromat's
          guess at a dichromat's experience, written in trichromat math
          and rendered on a trichromat-calibrated screen. It can't be
          right; it's the closest the chain knows how to come.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          You can measure the wavelength. You can measure the cones, the
          primaries, the categories language draws. The seeing, while
          you're in it, you can't.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          And it's the bigger problem under the obvious one. The
          obvious problem is that the simulation can't show you what
          I see. The bigger problem is that nothing on this page can
          show you what you're seeing — your having of the experience,
          right now, looking at this — is happening somewhere the page
          doesn't reach. The chain ends at the cone activation. The
          rest is on you.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          There's a thought experiment about a scientist who learns
          everything about red and then sees it. This is the inverse.
        </p>
      </.section>

      <.section number="7" id="closer" title="After">
        <.closer_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Light, eye, screen, word. Four parties, in the open. The
          chapter's been about them.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          You can probably play Lite Brite. You can probably tell when
          an avocado is ripe. Those things land in you differently than
          they would in me; either way, what they're like to land at
          all — your having of any of this — isn't on the page.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Never was. Couldn't be.
        </p>
      </.section>
    </article>
    """
  end

  attr :label, :string, required: true

  defp placecard(assigns) do
    ~H"""
    <div class="w-full rounded border border-dashed border-base-content/20 bg-base-200/20 px-6 py-20 flex items-center justify-center">
      <span class="font-mono text-xs uppercase tracking-widest text-base-content/35">
        {@label}
      </span>
    </div>
    """
  end

  attr :number, :string, default: nil
  attr :id, :string, required: true
  attr :title, :any, required: true

  slot :inner_block, required: true

  defp section(assigns) do
    ~H"""
    <section id={@id} class="mb-24">
      <h2 class="text-sm font-semibold uppercase tracking-widest text-base-content/85 mb-4">
        {@title}
      </h2>

      <div class="space-y-5">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  # ----- Section 1 hero splash: visible-spectrum strip -----
  # Currently swapped out for a placecard in §1; kept for when it returns.

  @compile {:nowarn_unused_functions, [hero_splash: 1]}

  @hero_lambda_step 2
  @hero_strips for l <- 380..700//@hero_lambda_step,
                   do: {l, Fugue.Color.Spectrum.hex(l)}

  defp hero_splash(assigns) do
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

  defp closer_splash(assigns) do
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
          aria-label="The same spectrum, returned. Nothing on the screen has changed."
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

  defp wcs_splash(assigns) do
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
      title: "splits of blue",
      anchor_hue_start: 450,
      anchor_hue_end: 510,
      rows: [
        %{language: "English", baseline: true, bounds: [{1.0, "blue"}]},
        %{language: "Russian", bounds: [{0.40, "синий"}, {1.0, "голубой"}]},
        %{language: "Mongolian", bounds: [{0.45, "хөх"}, {1.0, "цэнхэр"}]},
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
        %{language: "Vietnamese", bounds: [{1.0, "xanh"}]},
        %{language: "Japanese", bounds: [{0.55, "青 (ao)"}, {1.0, "緑 (midori)"}]},
        %{language: "Kazakh", bounds: [{0.50, "көк"}, {1.0, "жасыл"}]},
        %{language: "Navajo", bounds: [{1.0, "dootłʼizh"}]},
        %{language: "Himba", bounds: [{0.65, "burou"}, {1.0, "grine"}]}
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

  defp langs_splash(assigns) do
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
              x={cone_x_of(cone_peak(cone) + cone_shift(cone) + cone_label_dx(cone))}
              y={cone_y_of(1.0) - 8}
              text-anchor="middle"
              font-family="ui-monospace, monospace"
              font-size="12"
              fill={color}
            >
              μ_{cone_label(cone)}(λ)
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
          <span class="w-12 text-base-content/70">μ_{cone_label(a.cone)}</span>
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

  # CIE 1931 2-deg spectral locus (x, y) at 10 nm spacing, 380-700 nm.
  # Source: standard CIE tables.
  @spectral_locus [
    {380, 0.1741, 0.0050},
    {390, 0.1738, 0.0049},
    {400, 0.1733, 0.0048},
    {410, 0.1726, 0.0048},
    {420, 0.1714, 0.0051},
    {430, 0.1689, 0.0069},
    {440, 0.1644, 0.0109},
    {450, 0.1566, 0.0177},
    {460, 0.1440, 0.0297},
    {470, 0.1241, 0.0578},
    {480, 0.0913, 0.1327},
    {490, 0.0454, 0.2950},
    {500, 0.0082, 0.5384},
    {510, 0.0139, 0.7502},
    {520, 0.0743, 0.8338},
    {530, 0.1547, 0.8059},
    {540, 0.2296, 0.7543},
    {550, 0.3016, 0.6923},
    {560, 0.3731, 0.6245},
    {570, 0.4441, 0.5547},
    {580, 0.5125, 0.4866},
    {590, 0.5752, 0.4242},
    {600, 0.6270, 0.3725},
    {610, 0.6658, 0.3340},
    {620, 0.6915, 0.3083},
    {630, 0.7079, 0.2920},
    {640, 0.7190, 0.2809},
    {650, 0.7260, 0.2740},
    {660, 0.7300, 0.2700},
    {670, 0.7320, 0.2680},
    {680, 0.7334, 0.2666},
    {690, 0.7344, 0.2656},
    {700, 0.7347, 0.2653}
  ]

  # Display gamut primaries in CIE xy. White points (D65 ≈ 0.3127, 0.3290) ignored
  # for now; we are drawing the closed triangle of the primaries only.
  @gamut_srgb [{0.640, 0.330}, {0.300, 0.600}, {0.150, 0.060}]
  @gamut_dci_p3 [{0.680, 0.320}, {0.265, 0.690}, {0.150, 0.060}]
  @gamut_rec2020 [{0.708, 0.292}, {0.170, 0.797}, {0.131, 0.046}]

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
    cell_size = Fugue.Color.SrgbGamut.step() * 100 * 2.5

    assigns =
      assigns
      |> assign(:locus_points, locus_polyline_points())
      |> assign(:srgb_points, gamut_polygon_points(@gamut_srgb))
      |> assign(:p3_points, gamut_polygon_points(@gamut_dci_p3))
      |> assign(:rec2020_points, gamut_polygon_points(@gamut_rec2020))
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

  # Horizontal nudge (in nm) for label placement so the L and M labels
  # don't sit on top of each other when their peaks are close.
  defp cone_label_dx(:l), do: 12
  defp cone_label_dx(:m), do: -4
  defp cone_label_dx(_), do: 0

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
