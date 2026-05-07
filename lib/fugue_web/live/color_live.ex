defmodule FugueWeb.ColorLive do
  use FugueWeb, :live_view

  # Protan-metameric pairs for sections 3 + 6. Each {a, b, label} has been
  # verified to collapse to the same color under Machado severity-1.0
  # protanope simulation (delta <= 2 RGB units). Found by stepping along
  # the null vector of the Machado matrix in linear RGB. The set spans both
  # the canonical red/green (and its near neighbors) and a wider arc of
  # warm and cool collapses so section 6 isn't all greige.
  # Section 6 pins to a single pair from @metamer_pairs (no carousel -- it's
  # the echo of section 3, not a re-cycle). Index into the list below.
  @remainder_pair_index 7

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
     |> assign(:wcs_language, :english)
     |> assign(:metamer_index, 0)}
  end

  def handle_event("toggle_protanope", _params, socket) do
    {:noreply, assign(socket, :protanope, !socket.assigns.protanope)}
  end

  def handle_event("set_lambda", %{"lambda" => v}, socket) do
    {:noreply, assign(socket, :lambda, String.to_integer(v) * 1.0)}
  end

  def handle_event("cycle_metamer", %{"dir" => dir}, socket) do
    n = length(@metamer_pairs)
    i = socket.assigns.metamer_index

    new_i =
      case dir do
        "next" -> rem(i + 1, n)
        "prev" -> rem(i - 1 + n, n)
        _ -> i
      end

    {:noreply, assign(socket, :metamer_index, new_i)}
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
      <header class="mb-16 max-w-2xl">
        <h1 class="text-3xl font-bold tracking-tight text-base-content">
          Color.
        </h1>
        <p class="text-gray-500 mt-2 mb-10">
          Three cones, mostly.
        </p>
      </header>

      <.section number="1" id="light">
        <.iridescence_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          A cuttlefish presses against gravel and the gravel-color
          happens in its skin. Not pigment -- geometry. Stacks of
          crystal layers inside the cells, interfering with whatever
          light hits them, picking which wavelengths bounce back.
          The morpho butterfly does the same trick from a
          completely different phylum. Oil on a puddle, same
          trick. The color isn't in the thing.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Before going further: I can't actually see most of the
          colors I'm about to walk you through. I have two cones
          where standard issue is three. Christmas trees and their
          ornaments tend to merge on me; I read stoplights by
          position. I'm also bipolar and lefthanded, neither of
          which is relevant, but you're going to be in here a while
          and may as well know what kind of person you're following
          around.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Past red there's infrared, which is heat. Past violet
          there's ultraviolet, which is sunburn and skin cancer.
          Bees see the UV side. Snakes have a separate organ for
          infrared -- a literal pit in their face that picks up
          warm bodies in the dark. We get a strip in the middle,
          narrow, and we built every painting and every screen and
          every color word inside it.
        </p>
      </.section>

      <.section number="2" id="eye" title="The eye's guesses">
        <.cone_splash protanope={@protanope} lambda={@lambda} />

        <p class="text-sm text-base-content/65 leading-relaxed">
          OK so. Three cones. Each one is a sensor that gets excited
          about a stretch of wavelengths and bored about the rest;
          light hits the retina, three excitement levels come out,
          and those three numbers are everything your brain is ever
          going to be told about what's there. Thousands of
          distinguishable wavelengths in the world, smashed into a
          triple. That triple is your color. That's all you get.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          The cone curves overlap on purpose. A wavelength sitting
          in the seam between two of them lights both partly; the
          brain reads the ratio and assigns a name. Yellow is a
          ratio. Drag the slider above and watch the dots move --
          what you're seeing is how loud each cone is, which is the
          only thing the brain ever sees.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Now: I'm missing the L cone. The long one. The cone that's
          supposed to make "red" feel like a different flavor than
          "green." Without it my brain is running two channels
          where it's supposed to be running three, and the two it
          has are arguing about a problem that needs a third
          opinion. The argument keeps landing in roughly the same
          place. Christmas trees from across the room: fine. Up
          close, the ornaments and the needles agree about the
          color in a way they're not supposed to.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          And three isn't even fundamental. Some women have <em>four</em>
          cones -- they exist, there are studies, and they
          apparently see distinctions in beige paint the rest of us
          can't. Mantis shrimp have sixteen, which presumably means
          they think the rest of the ocean is functionally blind.
          Bees have three but their middle one is in the
          ultraviolet, and flowers turn out to have whole patterns
          painted on them in UV that we don't know are there.
          Snakes have an entirely separate organ for infrared.
          Snakes can see warm.
        </p>
      </.section>

      <.section number="3" id="metamerism" title="Two colors, same color">
        <p class="text-sm text-base-content/65 leading-relaxed">
          Two patches, two colors. Look at them. Now: underneath,
          the actual physical light coming off each patch is wildly
          different -- different mixes of wavelengths, almost no
          overlap. Your eye runs the average through three cones,
          gets two different triples out, and the brain reports two
          colors. The mix itself never lands. If two completely
          different mixes happen to give the same triple, the brain
          gets one color. Same patches, same eye, same brain --
          there's just no way for the system to know there was
          anything to disagree about.
        </p>

        <.metamer_splash protanope={@protanope} index={@metamer_index} />

        <p class="text-sm text-base-content/65 leading-relaxed">
          This is the trick your screen runs on. Every color it
          shows you is a fake. The yellow on this page isn't yellow
          light coming off the screen, it's red and green pixels
          sitting next to each other in a ratio the eye averages
          into yellow. There is no actual yellow involved anywhere.
          The eye never notices. Your phone, your TV, every monitor
          you've ever used -- the entire industry is built on a
          loophole in your retina.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          It's also why clothes look one color in the store and a
          different one at home. The lights in the store and the
          lights in your kitchen are different spectra, hitting the
          same shirt, getting averaged through your cones into
          different triples. The shirt didn't change. The light
          changed and your eye changed its mind. (Buy clothes
          outdoors.)
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Toggle the button above. The patches <em>were</em> two colors --
          now they're one color, and they haven't moved. My cones
          run the average and the average lands in the same place
          for both. To a trichromat looking at this: two clearly
          different patches. To me looking at this: one patch,
          twice.
        </p>
      </.section>

      <.section number="4" id="gamut" title="Where the screen can't reach">
        <.gamut_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          The filled-in triangle is your screen -- the colors it
          knows how to mix. The rings around it are fancier screens.
          The whole horseshoe shape is the set of colors a real eye
          can actually have. Your screen, your phone, the most
          expensive display you've ever sat in front of -- they all
          reach in and grab a triangle. They never get the rest.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Three primaries, three corners. The screen has a red
          pixel, a green pixel, and a blue pixel, and everything
          it ever shows you is a mix of those three. Anything
          outside the triangle is a color a real eye can have
          that the screen literally can't make.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          sRGB is what most monitors are doing. DCI-P3 is what
          newer phones and recent Apple laptops do. Rec.2020 is
          what high-end TV manufacturers gesture at and almost
          nobody actually owns. Bigger triangle, bigger triangle,
          bigger triangle. Still a triangle. Still missing the rim.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          That X is sitting at a real wavelength -- a deep spectral
          red, around 700 nanometers. Your eye can see it. A sunset
          is partly made of it. No screen in your life is going to
          render it accurately. I marked it with a wide-gamut
          color request, so on a fancier display it might look a
          touch more saturated than its surroundings; on a normal
          display it just gets clamped down to the closest red the
          monitor has. Either way, what you're looking at is the
          closest the box could come.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          And the whole diagram is trichromat. The map of what your
          screen can't reach was drawn so your screen could draw
          it. The chicken-and-egg there is on purpose -- it's
          basically the whole rest of the chapter.
        </p>
      </.section>

      <.section number="5" id="language" title="Language carves it up">
        <p class="text-sm text-base-content/65 leading-relaxed">
          OK so cones cut up the wavelengths. Then language comes
          in and cuts up the cones. And the kicker -- different
          languages cut them up in completely different places. The
          line your language drew is real to you and arguably
          invisible to someone whose language drew it somewhere
          else.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          How many words does a language need for color? Up to the
          language. English commits to eleven basic ones -- red,
          orange, yellow, green, blue, purple, pink, brown, black,
          white, grey. Some languages get by with two: one warm
          word, one cool word. Both languages work fine. Both sets
          of speakers are seeing the same wavelengths. Each one
          thinks its own partition is the obvious one.
        </p>

        <.wcs_splash language={@wcs_language} />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Each chip up there is painted with whichever term most
          speakers reached for; the opacity is how often they
          agreed on it. The faded chips are the ones the speakers
          argued about, which is itself information about where
          the language is firm and where it's improvising.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Berinmo cuts the green-yellow region in a place English
          doesn't. Berinmo speakers tell colors across that line
          apart faster than colors sitting on the same side of it.
          English speakers do the same thing across the green-blue
          line. The line your language drew did some actual work
          inside your head. The chip on the chart didn't change; <em>you</em>
          did, when you learned the word for it.
        </p>

        <.langs_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Russian splits blue in two: синий (siniy), голубой
          (goluboy). Mongolian splits it more dramatically: хөх
          (khökh) for winter ice, цэнхэр (tsenkher) for summer
          sky. Hungarian goes the other direction and
          splits red instead. None of these are translation
          problems. They're different cuts of the same continuous
          ribbon, and every cut goes all the way down -- it
          changes how fast the speaker can tell two chips apart,
          which is wild if you sit with it.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Some languages don't even cut along hue. Zulu -mnyama
          can cover black, dark blue, and dark green together;
          the partition is lightness, not position on the ribbon.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          And then -- across hundreds of languages -- there's a
          rough order things show up in. A language with three
          basic color words always uses black, white, and red. Add
          a fourth and you get green or yellow. Add a fifth and
          you get the other one. Blue shows up late. Possibly
          because blue is genuinely uncommon in nature outside the
          sky and even <em>that</em> took a while for various languages
          to commit to as a separate thing.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Some languages skip abstract color words entirely. Yélî
          Dnye, on Rossel Island, names colors by what they remind
          you of -- the night sky, ripe pandanus, burned wood,
          water at dusk. The comparison is doing the work the
          abstract word would do, and arguably doing it better;
          "burned wood" tells you more than "brown" if you've
          actually seen burned wood. Whose system is the weird one,
          exactly.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          And new color words are still being made up, right now.
          Crayola named Macaroni and Cheese, Razzmatazz, Outer
          Space. Pantone declared Living Coral the Color of the
          Year in 2019, like an emperor naming a province. New
          categories take when enough people use them and don't
          when they don't. Whatever chart of basic terms exists is
          still being argued over.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          I learned the word "red" before I figured out I wasn't
          seeing whatever the word was pointing at. The word still
          works fine for me -- I can buy red sweaters, mostly, on
          the second try. Some of the lines on that chart above
          are real to their speakers and invisible to me. I'm
          trusting the chart.
        </p>
      </.section>

      <.section number="6" id="remainder" title="What I can't show you">
        <p class="text-sm text-base-content/65 leading-relaxed">
          Everything so far had a number on it. This part
          doesn't.
        </p>

        <.remainder_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Look at those patches. Two patches, one color, to anyone
          looking at this page. (To me, this is a paragraph about
          two grey patches.) That simulation up there is a
          trichromat's guess at what dichromat experience is like,
          calculated in trichromat math, rendered on a trichromat
          screen. It can't actually be right. It's the closest the
          machinery knows how to come.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          And it goes the other direction too. You can measure the
          wavelength off a tomato. The cones, mine and yours. The
          screen. The word your language drops it into. All of
          that's on the table. The actual <em>seeing</em> of it, while
          you're inside your seeing of it, isn't.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          There's a smaller problem and a bigger one. The smaller
          one is that the simulation can't show you what I see. The
          bigger one is that nothing on this page can show you what <em>you</em>
          see. Your seeing is happening somewhere this page
          doesn't reach, and it's never going to. That's where the
          chapter ends.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          There's a thought experiment about a scientist who learns
          everything there is to know about red and then sees it
          for the first time. This is the inverse.
        </p>
      </.section>

      <.section number="7" id="closer" title="After">
        <.closer_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          The same spectrum, back where it started.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          You can probably play Lite Brite without consulting
          anyone. You can probably read a stoplight from a block
          away. Those events are landing inside you differently
          than they would inside me, and either way, what it's
          actually like for them to land at all isn't on this page.
        </p>
      </.section>
    </article>
    """
  end

  attr :number, :string, default: nil
  attr :id, :string, required: true
  attr :title, :any, default: nil

  slot :inner_block, required: true

  defp section(assigns) do
    ~H"""
    <section id={@id} class="mb-24">
      <h2
        :if={@title}
        class="text-sm font-semibold uppercase tracking-widest text-base-content/85 mb-4"
      >
        {@title}
      </h2>

      <div class="space-y-5">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  # ----- Section 1 hero splash: iridescent papillae -----
  # Cuttlefish-papillae thickness map driven by a Voronoi field, illuminated
  # by thin-film interference math. Cursor proximity sets the effective
  # viewing angle so the rainbow shifts as the reader hovers. Fragment
  # shader lives in assets/js/hooks/iridescence.js. The canvas is the hook
  # element directly (matches CloudsCanvas convention); phx-update="ignore"
  # keeps LiveView from clobbering it on re-render.

  defp iridescence_splash(assigns) do
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

  # ----- Section 1 spectrum strip: parked, kept for when it returns -----
  # Public (rather than defp) to dodge the unused-function warning while
  # the splash is on ice -- @compile :nowarn_unused_functions doesn't
  # silence Elixir's own version of this warning.

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

  defp remainder_splash(assigns) do
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

  attr :protanope, :boolean, required: true
  attr :index, :integer, required: true

  defp metamer_splash(assigns) do
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
