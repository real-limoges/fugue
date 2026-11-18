# Petri Wrapper Types

Declarations for the vendored petri wrappers in `assets/vendor/petri/js/`.

The vendor tree is an upstream drop and is never edited here, so the types live in this directory instead.
Code imports a wrapper as `petri/<sim>.js`.
esbuild resolves that through its `--alias:petri=./vendor/petri/js` flag (in `config/config.exs`), and `tsc` resolves it here through the `petri/*` entry in `assets/tsconfig.json`.

When petri is re-vendored, check each wrapper's exports against its declaration file.
Only the wrappers the site imports have one; `prism.js` is vendored but unused.
