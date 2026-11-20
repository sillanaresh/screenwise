# Screenwise

Native iOS app that ranks the screens at Hyderabad's top cinemas for a chosen movie. The full spec is
`docs/SPEC.md` (v2.0). Where this repo differs from it, `docs/decisions.md` says why. Read both
before changing behaviour.

## Architecture (simple version, see decisions D-02)

- No server, no database, no accounts. The app reads two JSON files:
  - `data/screens.json`: every venue and screen with per-field provenance. Edited by hand.
  - `data/catalogue.json`: the movie list. Written daily by `scripts/catalogue/sync.mjs` from TMDB
    (GitHub Action `catalogue.yml`, which needs the `TMDB_TOKEN` secret and runs on `main`).
- `data/film_formats.json`: hand-checked IMAX, Dolby Vision, HDR and frame ratio per TMDB id.
  The sync merges it. Movies without an entry get the default estimate (scope 2.39, animation 1.85).
- Both data files are bundled in the app for first launch and offline. The app then downloads
  fresh copies from `AppConfig.dataBaseURL` (the public repo's `main/data/` on GitHub).
- Unit tests use the 8 design sample movies in `fixtures/catalogue.sample.json`, not the live list.
- The TMDB token lives in `.env` locally (git ignores it) and as a GitHub secret. Never commit it.
- Scores are computed on the phone by the Swift port of `ref/score_v3.py` (v3, decision D-38).
- The 3D hall is three.js 0.160.0 in a WKWebView, served from the bundle through a custom
  `hallscene://` scheme (WebKit blocks ES modules from file URLs).

## Folder layout

```
Screenwise/
  App/            entry point, AppModel (state, routes, deep links), Info.plist
  Data/           DataStore (bundled + downloaded JSON), UserStore (saved, history, details)
  DesignSystem/   tokens, glass, Pill, ProvenanceMarker, GroupedBox, Toast, artwork
  Features/       Home, Movie, Theatre, Booking, Search, You, Explainers, Shared/Copy.swift
  HallScene/      HallHost (web views, bridge, thumbnails), scheme handler, SwiftUI views, 2D fallback
  Packages/ScreenwiseKit/   Models + Scoring (pure Swift, no UI; tested on the Mac)
  Resources/      Assets.xcassets (colour tokens), Localizable.xcstrings, PrivacyInfo, HallScene/ web files
  Tests/Unit, Tests/UI
data/  fixtures/scoring/  ref/score_v3.py (v2 kept for history)  scripts/  design/screenwise-prototype.html  docs/
```

## Naming

- Code and data say `film`. App copy says "movie", never "film".
- A venue is a building. A screen is one auditorium; copy calls it a theatre.
- Data keys are snake_case. Swift uses camelCase with explicit `CodingKeys`.
- Reason codes (`best_tech_black_room`, `picture_size_rank`, ...) live in `Scoring/Ranking.swift`;
  their sentences live in `Features/Shared/Copy.swift`. No language model writes ranking text.

## Design rules (spec 7)

- Colours only through `Color.sw.<token>`. Tokens come from `scripts/gen_colors.py`
  (light, dark, and Increase Contrast versions). Never put hex values in feature code.
  The one exception is data colours, such as a movie's `tint_hex`.
- One accent (red): Book tickets, Best pick, the selected row, kickers. Nothing else is red.
- `labelTertiary` is decoration only. Never use it for meaningful text.
- Type: system text styles only (`.largeTitle`, `.title2`, `.headline`, `.subheadline`,
  `.footnote` ...). No fixed font sizes. Add `.monospacedDigit()` to scores, sizes, angles, dates.
- Glass (`swGlass`) only for floating controls. Content cards use flat fills. Glass becomes solid
  `card` with Reduce Transparency or Increase Contrast.
- Radii: carousel card 28, sheet tops 28, theatre image 22, score box 18, grouped 16, tiles 12,
  buttons 14. Side margin 20. Touch targets at least 44 × 44.
- Motion: `Motion.push` (smooth 0.42) and `Motion.select` (snappy 0.25). Respect Reduce Motion.
- Copy: plain words, short sentences, no em or en dashes, middle dot ( · ) as a separator.
  Explainers stay under 60 words. A unit test checks the copy rules.

## Honesty rules (spec 1.3 and 8.3)

- Every spec field has a status: `sourced`, `unverified`, `conflicting` or `unknown`, plus source ids.
- Never invent a number. Unknown stays unknown. Estimates are labelled "est." or "estimated".
- Everything that shows a provenance marker also shows text or an accessibility label.
- `low confidence` means any of width, height, projection or sound isn't sourced.
- The 3D hall geometry is estimated unless published; the readout says "estimated".
- Fan graphics are never a confirmation. Conflicting fields list every value with its sources.
- A multiplex's screens with no published details share one "Regular screens" row (D-33).
  Cinema names on District count as `unverified`. Never draw a hall without a known size (D-35).

## Score v3 (spec 9, decision D-38)

Picture technology 35 · Sound 25 · Picture size 25 · Format match 15. Spectacle movies (Action,
Adventure, Science Fiction, Fantasy, War) use technology 30 and size 30. Premium projectors get
full points only when the movie has their version. Keep the Swift port's arithmetic in the same
order as `ref/score_v3.py`; parity tests compare totals bit for bit. Run `make fixtures` after
changing the reference.
Show scores with `Scorer.display` (round half up, once). Ties: unrounded total, area, name.

## Hall scene (spec 10)

- `Resources/HallScene/hall.js` is started from the prototype's `Hall` class. Swift calls
  `window.hall.build/setMode/setRow/rotate/zoom/snapshot`; JS posts `ready`,
  `interactionStarted`, `error` and forwarded `console` messages to the `hall` handler.
- SwiftUI owns all gestures and controls. Drags on the stage send `rotate(dx)`.
- One live web view is reused; one hidden web view renders card thumbnails one at a time,
  cached in Caches/hall-thumbs (200 max). Web views off screen are parked in a tiny holder in
  the key window, because WebKit suspends web views that aren't in a window.
- The readout uses `HallGeometry` maths in Swift, never pixels.
- Low Power Mode or no WebGL: `HallDrawing` (2D Canvas fallback).

## Commands

```
make bootstrap     # install XcodeGen if needed, generate Screenwise.xcodeproj
make build         # simulator build (SIM="iPhone 17 Pro" by default)
make test          # logic tests on the Mac (swift test), then app unit tests
make test-ui       # UI flows in the simulator
make run           # build, install and launch in the simulator
make lint          # swift format lint (config in .swift-format)
make fixtures      # regenerate fixtures/scoring from ref/score_v3.py
make colors        # regenerate colour tokens
make catalogue     # refresh data/catalogue.json from TMDB (needs TMDB_TOKEN)
cd scripts/catalogue && npm test   # sync script tests
```

The Xcode project is generated. Change `project.yml`, never the `.xcodeproj`.

Debug-only launch arguments for screenshots: `-openURL screenwise://...`, `-debugScrollY 600`,
`-debugStageMode seat`, `-debugSort near`, and `screenwise://debug/{explain/<term>|book/<film>/<screen>|sources/<screen>|all|about|tech|you|search}`.

## Open items

The Apple team is Z499BM27B6 (individual) and the bundle id is `app.screenwise.ios`.
Store text, URLs and privacy answers are in `docs/app-store.md`; the support page and privacy
policy are in `site/` (GitHub Pages). `make icon` redraws the icon, `make screenshots` remakes
the store screenshots, `make archive` builds for the App Store. Feedback emails go to
silla.naresh@gmail.com with the subject "Feedback: Screenwise" (`AppConfig`).
Still open: a domain of our own. See `docs/decisions.md`.
