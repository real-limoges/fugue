# Color chapter -- stub notes

Per-section drafting notes. Pair with `CLAUDE.md` in this directory for the
full design plan.

## Section 1 -- The prism

Hero is a visible-spectrum strip via `Fugue.Color.Spectrum` (Bruton's
piecewise wavelength-to-sRGB approximation). Stand-in for the parked prism;
easy to swap.

## Section 2 -- The eye's guesses

Draft prose. Fuzzy-frame sentence and personal beat are starter copy from the
plan; rework as needed. Wavelength slider is live -- uses
`Fugue.Color.Cones` (Stockman & Sharpe 2-deg, peak-normalized). `cones.wasm`
remains vendored if a richer interaction is wanted later.

## Section 3 -- Two colors, same color

v1: two patches that match for a protanope (no L) but differ for a normal
trichromat. Toggle is shared with section 2 via the `:protanope` assign. v2
could add the anomalous-trichromat midpoint (damaged L cone) and
hover-revealed spectral bars. The plan's "matches for trichromat / differs
for protanope" direction is mathematically impossible (a trichromat metamer
is automatically a dichromat metamer), so we use the achievable inverse
direction.

## Section 4 -- Where the screen can't reach

Shipped. Gamut horseshoe with sRGB / DCI-P3 / Rec.2020 triangles plus an
out-of-gamut **X marker** at ~650 nm spectral red. The X requests
`color(rec2020 1 0 0)` with an sRGB red fallback, so the marker asks for a
red the screen can't fully reach. No longer the cut candidate.

## Section 5 -- Language carves it up

Mock prose; iterate as desired.

- Splash 5a (WCS chip grid) uses mock English + Berinmo modal-term data via
  `Fugue.Color.WCSMock`. Real WCS aggregation is blocked on the Timbre repo
  bootstrapping (chip_id -> modal_term + consensus). Language toggle button
  cycles English / Berinmo.
- Splash 5b (multi-group language partition splash) is shipped with five
  groups: blue splits, red splits, green-blue meet, where the lines don't
  match (Berinmo nol/wor), and the warm side (Himba dumbu/serandu). English
  baselines per group. Native scripts where applicable.
- Open: drop one personal beat if both crowd; data sourcing for §5a (Timbre).

## Section 6 -- What I can't show you

Splash reuses section 3's protanope simulation; the failure caption is the
argument. Per tone calibration, lean fragmentary and curious; avoid academic
weight on the prose. Mary's Room inversion line lands after the argument is
made, not before. No Nagel, no Jackson by name.

**Do not** use the word "remainder" in the rendered title (saved feedback).
The id and the section's role name can stay `remainder` internally.

## Section 7 -- After

Closer is a short callback to the §1 spectrum strip. The fifth party (the
having) is deliberately left off the four-name list; that absence is the
point.