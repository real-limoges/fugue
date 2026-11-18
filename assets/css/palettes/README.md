# Palettes

Colors the daisyUI theme tokens don't cover: data series, figure accents, chart inks.
Each file defines custom properties twice, once for dark (`:root, [data-theme=dark]`) and once for light (`[data-theme=light]`), and markup or JS refers to them as `var(--name)`.

The light values are guided by the dotfiles palette solver (`~/repositories/dotfiles/color/`), not run through it.
The paper is `#f2e9d8`.
Text colors clear 4.5:1 on it, lines and fills that carry meaning clear 3:1, and series that must be told apart stay apart for protan and deutan observers as well as normal ones.
The solved light syntax hues are the starting set: magenta `#a7037b`, blue-teal `#045b80`, green `#036831`, orange `#b33204`, violet `#8620d9`, red `#780404`, indigo `#1b25e3`.

Dark values are the colors the site shipped with, unchanged.

| File | Area |
|---|---|
| `site.css` | Shared chrome and page-level accents |
| `mood.css` | `/mood`: cluster palette, dimension palette, figure inks |
| `color.css` | `/color`: cone curves and figure accents |
| `menagerie.css` | `/menagerie` and `/lab` charts |

Canvas code can't paint `var(--x)`; resolve it with `resolveCssVar` from `assets/js/lib/theme_colors.js`, and resolve again on the `fugue:theme-changed` window event.
