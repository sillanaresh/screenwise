# Decisions

This file records each place where the build differs from `docs/SPEC.md` (v2.0), and why.
The owner reviewed the gaps on 19 Nov 2026. They asked for the simple version (D-02) and left
the smaller calls to the builder's judgment.

## Scope

**D-02. The simple version: no server in v1.** Approved by the owner on 19 Nov 2026.
- Dropped for v1: Supabase, Edge Functions, the AI research agents, live "Find this movie"
  research with push notifications, the daily showtime listing check, the admin website and
  the review queue.
- The app reads two JSON files instead: `data/screens.json` (theatres, edited by hand) and
  `data/catalogue.json` (movies, written daily from TMDB by a GitHub Action).
- Scores are computed on the phone, so there is no TypeScript scorer. The Swift scorer has
  bit-for-bit parity tests against `ref/score_v2.py`.
- Update cadence: movies every day, theatres reviewed every week or two, and formats checked
  by hand for big releases. The About sheet explains this to users.
- The M0 "seed loader" is a one-time conversion of `seed_screens.json` into `data/screens.json`.
  It keeps every value, status and source.

**D-17. Corrections and feedback go by email.** Report a correction, Tell us about this movie
and Send feedback open the mail composer with the details filled in. If Mail isn't set up, the
app opens a `mailto:` link or shows the address. Emails go to silla.naresh@gmail.com, always
with the subject line "Feedback: Screenwise" (owner's choice, 19 Nov 2026). The kind of message
and the theatre or movie go in the first lines of the body.

**D-18. Search with no match.** Search shows "Not on Screenwise yet" and explains that new
movies appear daily, with a "Tell us about this movie" button. There is no live research in v1.

**D-04. No release reminders switch in v1.** The spec lists the release-day notification as
v1.1, so a v1 switch would do nothing. Settings has "Send feedback" in its place.

**D-05. No analytics in v1.** There is no server to receive events. The privacy manifest
declares no collected data.

## Data

**D-01. AAA Screen 2 is ranked.** It is in the seed with sourced specs (30 × 16 ft EPIQ LED),
but the reference script and prototype rank only 9 screens. Leaving out a real screen would
hide data, so it is ranked. It scores 61 for Avengers: Doomsday and comes last. The parity
fixtures still use the reference's 9 screens.

**D-06. AAA Screen 1 width is `unverified`.** The only source says "67 feet high". It almost
certainly means wide, but the spec's honesty rule needs a clear source.

**D-08. Upcoming screens.** Each upcoming venue is a venue with status `upcoming`. Where a
headline screen is named, it is also a screen with status `upcoming`, which is never ranked.
`expected_open_by` holds a date (the latest likely opening), so the Opening soon rule can
compare it with a release date. Every number for an upcoming screen is `unverified`, because
it is a plan and not yet a fact. Kompally has no named screen, so it has no screen entry.

**D-09. "In cinemas" comes from the India release date.** The listing check is dropped (D-02).

**D-10. Display names.** Cards show the venue name from the seed (for example "Prasads
Multiplex"), a short hall label (`hall`, for example "Screen 6 PCX") and a short format label
(`format_label`). The prototype's "Prasads PCX" and "Large format" are not used.

**D-21. Generated artwork when there is none.** TMDB was connected on 19 Nov 2026, and the
first sync found 247 movies. When a movie has no artwork on TMDB, the app shows a soft colour
field made from its tint, never a fake poster.

**D-22. Carousel window.** The spec's rule (released in the last 30 days or due in the next 120)
leaves out Varanasi (7 Apr 2027), which the prototype showed. The spec wins.

**D-25. Search aliases come from TMDB alternative titles.** The spec generates Latin
spellings with a language model. In v1 the sync uses TMDB's alternative titles from India, the
US and the UK, written in plain English letters. Other countries' titles were mostly
translations, such as "Vahşi Orman" for Wildwood, which only add noise to search.

**D-31. Anticipation without news data.** The spec ranks the Home carousel by 0.6 × TMDB
popularity plus 0.4 × Indian news mentions. There is no mention data in the simple version.
Raw popularity put eight Hollywood movies ahead of every Telugu and Hindi release, which is
wrong for Hyderabad. So the sync compares popularity within each language (square root of the
share of that language's most popular movie), then weights it by language: Telugu 1.0,
Hindi 0.9, English 0.85, Tamil 0.8, Malayalam and Kannada 0.6, others 0.45. This changes
ordering only, never scores. Revisit it when mention data exists.

**D-32. Colourless textless posters are skipped.** The spec prefers a textless poster, then a
backdrop, then a titled poster. For some movies TMDB's only textless poster is a teaser sketch.
Ghost Soldier's is a white knife drawing on black, which looks like a missing image on a card.
So when a textless poster has almost no colour (fewer than 20 coloured sample points, the same
test that gives the default tint), the sync drops it and uses the backdrop photo. The default
tint is never reused from the last list, so these movies are checked again each day.

**Sample movies for tests.** The design's 8 sample movies live on in
`fixtures/catalogue.sample.json`, so the app's unit tests don't change when the daily list does.

## Ranking text

**D-07. Reason codes.** The spec gives 7 example codes. The full set is in
`Scoring/Ranking.swift`, and the sentences are in `Features/Shared/Copy.swift`.
- Main reason: the part of the score where the screen beats the city median by the most.
  Ties go to tech, then sound, then size, then format.
  - Tech: `best_tech_black_room` (Dolby Cinema, only when it is the city's best),
    `hdr_fills_scope` (HDR on a scope screen this movie fills), `hdr_bright`, `imax_picture`,
    `led_picture`, `strong_picture`.
  - Sound: `dolby_cinema_sound`, `imax_sound`, `strong_sound`.
  - Size: `biggest_picture` (#1 by area), `big_picture` (#2 or #3), `bigger_picture`.
  - Format: `special_version` (gets a Dolby Vision, IMAX or HDR version) or `shape_match`.
  - Fallback, when a screen isn't above the median on anything: `tech_and_sound`, for example
    "4K laser projection with Dolby Atmos sound." It is always true from the data.
- Pros (2 to 4): the main reason, then `picture_size_rank`, then shape match, special version,
  and better than median sound or tech.
- Cons: `flat_screen_bands`, `tall_screen_bands` (with the percent of height used),
  `scope_screen_bars`, `smallest_picture`, review codes such as `side_seats_poor`, and
  "not confirmed" or "reports differ" lines for size, projector, sound and seats.
- `far_from_centre` is not used. It needs venue coordinates, and the seed has none.

**D-03. Explainer copy.** The spec says to use the prototype's explainer text and also never to
say "film" in the app, with each explainer under 60 words. The prototype text uses "film" and
some entries are longer, so the text is rewritten in the same voice. A unit test checks both
rules. The IMAX explainer avoids a hard-coded date, and its wording changes once an IMAX
screen opens. LED cinema screen, PCX, RGB laser and DTS:X were added.

**D-30. Unknown values show "?".** The prototype shows an en dash for unknown seats, which
breaks the copy rule.

## Hall scene

**D-12. Custom URL scheme instead of `loadFileURL`.** WebKit refuses ES module imports from
file URLs, so a `WKURLSchemeHandler` serves `hallscene://app/...` from the bundle. Movie
pictures are served the same way, which keeps the WebGL textures same-origin.

**D-13. SwiftUI owns the gestures.** The stage's controls live in the scroll view, so the sheet
can slide over them. A horizontal drag turns the hall, a vertical drag scrolls the page, and a
pinch zooms. A small orbit control in `hall.js` replaces three.js OrbitControls, with the same
limits (azimuth ±1.05, zoom 0.55 to 1.5 times the fit distance) and the same idle sway.

**D-11. Seat count and triangles.** The spec's seats-per-row formula draws about 780 seats for
Allu's 644. Seats per row are capped, so the model draws close to the published count, for
example 660. The seat is about 144 triangles. A large hall is about 97,000 triangles, which is
over the spec's 40,000 budget. It runs well in the simulator. Profile it on an iPhone 13 in M4.
If it misses 60 fps, switch to plain box seats (48 triangles each).

**D-14. Live framing margin.** The controls and the sheet cover the lower part of the stage, so
the live camera sits 1.16 times farther back than the fitted distance. Thumbnails use the exact
fit.

**D-27. Dark mode hall lighting follows the spec values.** The halls look quite dark in dark
mode. The owner should review this on a device.

**Web views stay warm.** WebKit suspends web views that aren't in a window. Off-screen web views
wait in a 1 × 1 holder inside the key window.

## App structure

**D-15. One logic package.** `ScreenwiseKit` holds `Models` and `Scoring` (including the hall
maths), so tests run on the Mac in seconds. The UI lives in folders in the app target.
Networking and Persistence are one small `Data` folder, because there is no server.

**D-16. No SwiftData.** Saved theatres, history and details are one small JSON file. The movie
cache is the downloaded file itself.

**D-19. Deep links use `screenwise://` only.** Universal links wait for the domain (open question).

**D-20. Snapshot tests are not added yet.** Screens were checked by simulator screenshots in
light and dark. Add `swift-snapshot-testing` in M1 polish.

**D-23. Booking links.** No venue booking URLs are known yet, so both rows open the BookMyShow
Hyderabad page or District's movies page, with the subtitle "Search for this theatre there".
When a venue's real page URL is added to `data/screens.json`, the subtitle changes to
"Opens this theatre's page".

**D-24. TMDB logo.** About has the TMDB notice, but not the logo yet. Download an approved
logo from TMDB's logos page and add it, less prominent than our branding.

**D-26. Placeholders.** The bundle id `app.screenwise.ios` and an empty development team are
placeholders until the owner answers open question 4.

## Still open (owner)

1. App name and domain.
2. Apple Developer team and bundle id.
4. What the optional name, mobile and email are for. In v1 they stay on the phone.
5. Which movies may appear in App Store screenshots.

Resolved on 19 Nov 2026: the repo is public, and the app downloads the two data files from its
`main` branch on GitHub.
