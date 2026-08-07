defmodule FugueWeb.ColorLive do
  @moduledoc """
  Top-level LiveView for `/color`, the protanopia-threaded chapter on
  color science. Owns the chapter's interactive state (protanope
  toggle, single-wavelength `lambda` slider, WCS chip-grid language,
  and metamer-pair index) and renders the section bodies through
  `FugueWeb.ColorLive.Splashes`.
  """
  use FugueWeb, :live_view

  alias FugueWeb.ColorLive.Splashes

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
     |> assign(:wcs_language, :tarahumara)
     |> assign(:metamer_index, 0)}
  end

  def handle_event("toggle_protanope", _params, socket) do
    {:noreply, assign(socket, :protanope, !socket.assigns.protanope)}
  end

  def handle_event("set_lambda", %{"lambda" => v}, socket) do
    {:noreply, assign(socket, :lambda, String.to_integer(v) * 1.0)}
  end

  def handle_event("cycle_metamer", %{"dir" => dir}, socket) do
    n = Splashes.metamer_pair_count()
    i = socket.assigns.metamer_index

    new_i =
      case dir do
        "next" -> rem(i + 1, n)
        "prev" -> rem(i - 1 + n, n)
        _ -> i
      end

    {:noreply, assign(socket, :metamer_index, new_i)}
  end

  def handle_event("cycle_wcs_language", %{"dir" => dir}, socket) do
    langs = Fugue.Color.WCS.languages()
    n = length(langs)
    i = Enum.find_index(langs, &(&1 == socket.assigns.wcs_language))

    new_i =
      case dir do
        "next" -> rem(i + 1, n)
        "prev" -> rem(i - 1 + n, n)
        _ -> i
      end

    {:noreply, assign(socket, :wcs_language, Enum.at(langs, new_i))}
  end

  def render(assigns) do
    ~H"""
    <article class="px-4 py-8 max-w-3xl mx-auto">
      <header class="mb-16 max-w-2xl">
        <h1 class="text-3xl font-bold tracking-tight text-base-content">
          Color.
        </h1>
        <p class="text-gray-500 mt-2 mb-10">
          Three cones, give or take.
        </p>
      </header>

      <.section number="1" id="light">
        <Splashes.iridescence_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          A cuttlefish presses against gravel and the gravel-color
          happens in its skin. It's geometry, not pigment. Stacks of
          crystal layers inside the cells, interfering with whatever
          light hits them, picking which wavelengths bounce back.
          The morpho butterfly does the same trick from a
          completely different phylum. Oil on a puddle, same trick.
          Move your head and the color moves with you.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Before going further: I can't see most of the colors I'm
          about to walk you through. I have two cones where standard
          issue is three. Christmas trees and their ornaments tend to
          merge on me; I read stoplights by position. I'm also
          bipolar and lefthanded, neither of which is relevant, but
          you may as well know what kind of person you're following
          around.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Past red there's infrared, which is heat. Past violet
          there's ultraviolet, which is sunburn and skin cancer.
          Bees see the UV side. Snakes have a separate organ for
          infrared, a literal pit in their face that picks up
          warm bodies in the dark. We get a narrow strip in the
          middle, roughly 400 to 700 nanometers, and we built every
          painting and every screen and every color word inside it.
        </p>
      </.section>

      <.section number="2" id="eye" title="The eye's guesses">
        <Splashes.cone_splash protanope={@protanope} lambda={@lambda} />

        <p class="text-sm text-base-content/65 leading-relaxed">
          OK so. Three cones. Each one is a sensor that gets excited
          about a stretch of wavelengths and bored about the rest;
          light hits the retina, three excitement levels come out,
          and those three numbers are everything your brain is ever
          going to be told about what's there. Thousands of
          distinguishable wavelengths in the world, smashed down
          into a triple. That triple is your color.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          The cone curves overlap on purpose. A wavelength sitting
          in the seam between two of them lights both partly, and
          the brain reads the ratio and assigns a name. Yellow is
          a ratio, not something your eye has a dedicated sensor
          for. Drag the slider above and watch the dots move. The
          height of each dot is how loud that cone is.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Now: I'm missing the L cone. The long one. The cone that's
          supposed to make "red" feel like a different flavor than
          "green." Without it my brain is running two channels
          where it's supposed to be running three, and the two it
          has keep landing in roughly the same place on a question
          that needs a third opinion. Christmas trees from across
          the room: fine. Up close, the ornaments and the needles
          agree about the color in a way they're not supposed to.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          And three isn't even fundamental. Some women have <em>four</em>
          cones. They exist, there are studies, and they
          apparently see distinctions in beige paint the rest of us
          can't. Mantis shrimp have sixteen, which presumably means
          they think the rest of the ocean is functionally blind.
          Bees have three but their middle one sits in the
          ultraviolet, so flowers have whole patterns painted on
          them (landing strips, bullseyes) that we don't know are
          there. Snakes have an entirely separate organ for
          infrared. Snakes can see warm.
        </p>
      </.section>

      <.section number="3" id="metamerism" title="Two colors, same color">
        <p class="text-sm text-base-content/65 leading-relaxed">
          Two patches, two colors. Look at them. Now: underneath,
          the physical light coming off each patch is wildly
          different. Different mixes of wavelengths, almost no
          overlap. Your eye runs each mix through three cones, gets
          two different triples out, and reports two colors. The mix
          itself never reaches you; only the triple does. So if two
          completely different mixes happen to produce the same
          triple, you get one color, and nothing downstream has any
          way of knowing there was ever anything to disagree about.
        </p>

        <Splashes.metamer_splash protanope={@protanope} index={@metamer_index} />

        <p class="text-sm text-base-content/65 leading-relaxed">
          This is what your screen runs on. Every color it shows you
          is a fake. The yellow on this page isn't yellow light
          coming off the glass, it's red and green pixels sitting
          next to each other in a ratio your eye averages into
          yellow. No yellow is involved anywhere and your eye
          doesn't notice. Your phone is doing it, your TV is doing
          it, every monitor you've ever used has been doing it. The
          entire industry is built on a loophole in your retina.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          It's also why clothes look one color in the store and a
          different one at home. The lights in the store and the
          lights in your kitchen are different spectra, hitting the
          same shirt, getting averaged through your cones into
          different triples. The shirt never changed; the light did.
          (Buy clothes outdoors.)
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Toggle the button above. The patches <em>were</em> two colors.
          Now they're one color, and they haven't moved. My cones
          run the average and it lands in the same place for both.
          To a trichromat looking at this: two clearly different
          patches. To me looking at this: one patch, twice.
        </p>
      </.section>

      <.section number="4" id="gamut" title="Where the screen can't reach">
        <Splashes.gamut_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          The filled-in triangle is your screen, the colors it
          knows how to mix. The rings around it are fancier screens.
          The whole horseshoe is the set of colors a real eye can
          have. Every display ever built reaches into that horseshoe
          and grabs a triangle. None of them get the rest.
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
          nobody owns. Bigger triangle, bigger triangle, bigger
          triangle. Still a triangle. Still missing the rim.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          That X is sitting at a real wavelength: a deep spectral
          red, around 700 nanometers. Your eye can see it, a sunset
          is partly made of it, and no screen in your life is going
          to render it accurately. I marked it with a wide-gamut
          color request, so on a fancier display it might look a
          touch more saturated than its surroundings. On a normal
          display it gets clamped down to the closest red the
          monitor has, which is probably what you're looking at.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          And the whole diagram is trichromat. The map of what your
          screen can't reach was itself drawn to be drawable by
          your screen. The horseshoe you're looking at is already a
          compromise.
        </p>
      </.section>

      <.section number="5" id="language" title="Language carves it up">
        <p class="text-sm text-base-content/65 leading-relaxed">
          OK so cones cut up the wavelengths. Then language comes
          in and cuts up the cones, and different languages cut them
          in completely different places. The line your language
          drew feels obvious to you and can be invisible to someone
          whose language drew it somewhere else.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          How many words does a language need for color? Up to the
          language. English commits to eleven basic ones: red,
          orange, yellow, green, blue, purple, pink, brown, black,
          white, grey. Some languages get by with two: one warm
          word, one cool word. Both work fine for the people
          speaking them, and both sets of speakers are looking at
          the same wavelengths. Each one thinks its own partition is
          the obvious one.
        </p>

        <Splashes.wcs_splash language={@wcs_language} />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Each chip up there is painted with whichever term most
          speakers reached for; the opacity is how often they
          agreed on it. The faded chips are the ones the speakers
          argued about, the places where the language hasn't
          settled.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          The toggle cycles four languages from the survey, and
          none of them carve it the way English does. Nafaanra runs
          the whole grid on three words. Tarahumara has one word,
          siyó, stretched across green and blue together, a single
          color where English insists on two. Whether the seam
          between green and blue is one thing or two isn't in the
          chips; it's in the speaker. English speakers tell two
          chips apart faster when a name-boundary falls between
          them, so the boundary did some actual work inside the
          head. The chip on the chart didn't change; <em>you</em>
          did, when you learned the word for it.
        </p>

        <Splashes.langs_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Russian splits blue in two: синий (siniy), голубой
          (goluboy). Mongolian splits it more dramatically: хөх
          (khökh) for winter ice, цэнхэр (tsenkher) for summer
          sky. Hungarian goes the other direction and
          splits red instead. None of these are translation
          problems. They're different cuts of the same continuous
          ribbon, and every cut goes all the way down. It changes
          how fast the speaker can tell two chips apart, which is
          wild if you sit with it.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Some languages don't even cut along hue. Zulu -mnyama
          can cover black, dark blue, and dark green together;
          the partition is lightness, not position on the ribbon.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          And then, across hundreds of languages, there's a
          rough order things show up in. A language with three
          basic color words always uses black, white, and red. Add
          a fourth and you get green or yellow. Add a fifth and
          you get the other one. Blue shows up late, possibly
          because blue is uncommon in nature outside the sky, and
          even <em>that</em> took a while for various languages
          to commit to as a separate thing.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Some languages skip abstract color words entirely. Yélî
          Dnye, on Rossel Island, names colors by what they remind
          you of: the night sky, ripe pandanus, burned wood,
          water at dusk. The comparison does the work the abstract
          word would do, and it carries more with it; "burned wood"
          tells you more than "brown" does, assuming you've seen
          burned wood. Whose system is the weird one.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          And new color words are still being made up, right now.
          Crayola named Macaroni and Cheese, Razzmatazz, Outer
          Space. Pantone declared Living Coral the Color of the
          Year in 2019, like an emperor naming a province. A few of
          these stick and most of them don't, and the list of basic
          terms is still being argued over.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          I learned the word "red" before I figured out I wasn't
          seeing whatever the word was pointing at. The word still
          works fine for me. I can usually buy red sweaters on
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

        <Splashes.remainder_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Look at those patches. Two patches, one color, to anyone
          looking at this page. (To me, this is a paragraph about
          two grey patches.) That simulation up there is a
          trichromat's guess at what dichromat experience is like,
          calculated in trichromat math and rendered on a
          trichromat screen. Nobody who built it has seen the thing
          it's trying to show you.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          And it goes the other direction too. You can measure the
          wavelength coming off a tomato, model the cones that catch
          it, characterize the screen, name the word your language
          drops it into. All of that is on the table. The <em>seeing</em>
          of it, while you're inside your seeing of it, isn't.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          There's a smaller problem and a bigger one. The smaller
          one is that the simulation can't show you what I see. The
          bigger one is that nothing on this page can show you what <em>you</em>
          see. Your seeing is happening somewhere this page doesn't
          reach.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          There's a thought experiment about a scientist who learns
          everything there is to know about red and then sees it
          for the first time. I've been running it backwards my
          whole life.
        </p>
      </.section>

      <.section number="7" id="closer" title="After">
        <Splashes.closer_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          The same spectrum, back where it started.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          You can probably play Lite Brite without consulting
          anyone, and read a stoplight from a block away without
          checking which lamp is lit. Those events land inside you
          differently than they'd land inside me. What it's like for
          them to land at all was never going to fit on this page.
        </p>
      </.section>

      <.source_link repos={["Timbre", {"fugue", "lib/fugue_web/live/color_live"}]} />
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
end
