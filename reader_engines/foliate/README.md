# Foliate-js Renderer (ADR-001)

**Pinned commit:** `22a49acaa120877ede21f713679ab8ba4d1ef663`
**Source:** https://github.com/readest/foliate-js
**License:** MIT (Copyright (c) 2022 John Factotum)
**Pinned date:** 2026-11-14

## Asset layout

- `foliate-js/` — vendored source (commit above). Do not edit directly; record patches in `PATCH_LEDGER.md`.
- `assets/` (to be created) — built/bundled output loaded by WebView.
- `build.sh` / `build.ps1` — reproducible offline asset build.

## Reproducible build

1. `cd reader_engines/foliate/foliate-js`
2. `npm ci` (uses committed `package-lock.json`)
3. `npm run build` (rollup) → output to `../assets/`
4. Verify checksums.

## License audit

- foliate-js: MIT.
- Dependencies (zip.js, fflate, etc.): see `vendor/` and package-lock.json; audit before release (SEC-001).
