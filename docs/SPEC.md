# Screenwise: build spec for Claude Code

Working title: **Screenwise** (the name is Open, section 16). Tagline: *Pick a movie. We'll pick the theatre.*
Platform: native iOS (iPhone first). City at launch: Hyderabad.
Spec version: 2.0, 19 Nov 2026. Owner: Bruce. This version replaces 1.0. It changes the design (light and dark, iOS-native, Airbnb and Apple TV quality), the navigation, the 3D approach and the score weights.

---

## 0. How to use this document

You are Claude Code. This file is the source of truth for building Screenwise. Read it fully before writing code. Then follow the milestones in section 15 in order, and check each milestone's acceptance criteria before moving on.

The hand-off package contains:

| File | What it is |
|---|---|
| `SPEC.md` | This document. |
| `design/screenwise-prototype.html` | The approved design. It's a working single-file prototype of the whole app in light and dark. Read exact layout, copy, colours, radii, spacing and motion from it. Its three.js hall scene is the starting point for the real one (section 10). Everything else in it is reference, not code to ship. |
| `seed_screens.json` | Starter data for Hyderabad screens, with a source and a status on every field. |
| `ref/score_v2.py` | Reference implementation of the Screen Score v2. Your Swift and TypeScript versions must match its output exactly (section 9.7). |

**How to read the prototype:**
- Open it in Chrome or Safari with the device toolbar at 402 × 874 (iPhone 17 Pro size). Switch the system appearance, or use You → Appearance inside the prototype, to see light and dark.
- It loads three.js 0.160.0 and the Inter font from CDNs. Inter only stands in for SF Pro on machines without Apple fonts.
- In the browser console, `window.__sw` has shortcuts: `openFilm(i)`, `openTheatre(rank)`, `setMode('hall' | 'seat')`, `setRow(i)`, `explain('dolbyvision')`.
- Its posters are generated stand-in artwork, because real studio posters can't go in a design file. The app uses TMDB artwork (section 5.2). Its movie list is sample data. Its theatre data is a simplified copy of `seed_screens.json`.
- Where the prototype and this spec disagree, the spec wins. Note the difference in `docs/decisions.md`.

Bruce's live copy of the prototype is at `https://claude.ai/artifact/W4GcwxfWW4XaZAQzQUjsN9`. It's private to him, so you can't open it. Use the file in the package.

**Decision status.** Every decision in this spec is one of three things:

- **Decided:** build it as written.
- **Default:** a choice made for v1 that you may change if you find a concrete reason. Write the reason in `docs/decisions.md`.
- **Open:** listed in section 16. Don't guess. Ask Bruce.

**First task in the repo.** Create `CLAUDE.md` at the repo root that summarises sections 3, 7, 10, 12 and 13 in under 150 lines: architecture, folder layout, naming, the token and type rules, the honesty rules and the test commands. Keep it current as the build moves.

**Writing style for all user-facing copy:** plain words, short sentences, active voice. Say "movie" in the app, never "film". (Code and data keep the word `film`.) Never use em dashes or en dashes in app copy. Use a middle dot ( · ) as a separator.

---

## 1. Product

### 1.1 The problem

Hyderabad now has very different premium screens: a Dolby Cinema at Allu Cinemas, HDR by Barco at AMB and Prasads, the 101.6 × 64 ft PCX at Prasads, big laser single screens such as Mythri Vimal, and IMAX coming back at AMB Classic Victory. Booking apps list showtimes, but they don't answer the real question a movie fan has: **for this movie, which theatre gives me the best picture and sound?**

That answer depends on the movie. A scope (2.39:1) movie loses height on a flat screen. A flat (1.85:1) movie loses width on a scope screen. A movie shot for IMAX only shows its taller scenes in IMAX. A Dolby Vision grade only plays in Dolby Cinema. Today people work this out from fan graphics with unsourced numbers.

### 1.2 What Screenwise does

1. Shows every current and upcoming movie that will play in Hyderabad, in every Indian language plus major Hollywood releases.
2. For any movie, ranks every Hyderabad screen with a **Screen Score** for *that movie*, and explains why in one line.
3. Shows what you'll actually get: a 3D model of each hall with the movie on its screen, and the view from any row.
4. Explains every technical term in simple English.
5. Sends you to BookMyShow or District to book. Screenwise never sells tickets and never shows showtimes or prices in v1.
6. If a movie is missing, any user can tap **Find this movie**. Backend agents research it and notify the user when it's ready.

### 1.3 Product principles (Decided)

1. **Movie first, not theatre first.** Every ranking is for a specific movie.
2. **Quality over size.** Picture quality and sound count for more than raw screen size (section 9).
3. **Honest data.** Every spec shows where it came from. Estimates look different from facts. We never invent a number. When we don't know, we say so.
4. **Show, don't tell.** Prefer the 3D hall and the view from a seat over a paragraph about screen size.
5. **Calm and native.** It should feel like a first-party Apple app, at the level of the Apple TV app and Airbnb: big imagery, generous space, system components. It follows the phone's light or dark setting, with equal care for both.
6. **Plain English.** Every term such as Dolby Vision, HDR by Barco, 4K laser, Atmos or scope has a "?" that explains it in one or two simple sentences.
7. **Light hero pages.** Home, Movie and Theatre show only what helps you choose. Dense tables live under You.
8. **One accent, used with meaning.** Red marks the main action (Book tickets), the best pick and selected states. Nothing else is red.
9. **Fast.** Cached content on screen in under 1 second from a cold start.

### 1.4 Non-goals for v1 (Decided)

- No ticket booking, showtimes, prices or seat maps from booking apps.
- No user reviews, comments or social features.
- No cities other than Hyderabad, though the data model supports more (section 8).
- No Android, iPad-specific layout or web app. iPad runs the iPhone layout.
- No accounts. The app works fully without sign-in. The optional name, mobile and email stay on the phone in v1.

### 1.5 Audience and launch (Decided)

Free public app on the App Store. No ads, no in-app purchases in v1. A paid tier may come later. Section 14.1 explains why that matters for the TMDB licence.

---

## 2. Users and jobs

| Person | Job | What they need from the app |
|---|---|---|
| Movie fan planning a big release | "Where should I watch *Avengers: Doomsday* on day one?" | The ranked list, the 3D hall, the view from a seat, and a fast path to booking. |
| Casual viewer | "Is the big screen near me good for this movie?" | The score in plain words, one clear recommendation, simple explanations of the tech. |
| Group planner | "Which hall works for 6 of us?" | Area, seat count, and a link to share. |
| Curious fan | "How big is PCX compared with Allu's Dolby?" | All Hyderabad screens under You, the 3D halls, the explainers. |

Success for v1: a user who opens a Movie page knows within 10 seconds which theatre to book and why, and trusts the answer enough to book it.

---

## 3. Core concepts and glossary

These words appear in code, data and copy. Use them consistently.

| Term | Meaning |
|---|---|
| **Film frame** (aspect ratio) | The shape of the movie's picture, width divided by height. Common values: `scope` 2.39:1, `flat` 1.85:1, `imax_190` 1.90:1, `imax_143` 1.43:1. Some movies use others such as 2.00:1 or 2.20:1. Store the exact number. |
| **Expanded-ratio version** | A version of a movie with taller scenes, released only to IMAX (1.90 or 1.43). |
| **Premium version** | A version made for a format: `imax`, `dolby_vision`, `hdr_barco`, `3d`. Each has a status: `confirmed`, `expected` or `none`. |
| **Screen surface** | The physical screen, width × height in feet. |
| **Screen shape** | Screen width ÷ height. The app shows it as Scope (over 2.2), Flat (1.7 to 2.2) or Tall (under 1.7). |
| **Picture for this movie** | The largest rectangle in the movie's frame that fits the screen surface. If the screen is narrower than the movie's frame (in ratio), the picture uses full width ("constant width"). Otherwise it uses full height ("constant height"). |
| **Bands** | The unused screen above and below (letterbox) or at the sides (pillarbox) of the picture. |
| **Screen Score** | 0 to 100 score of one screen for one movie. Section 9. |
| **Band name** | The word next to the score: Reference, Excellent, Great, Good, Standard. |
| **Provenance status** | Per data field: `sourced`, `unverified`, `conflicting`, `unknown`. Section 8.3. |
| **Hall model** | The 3D cutaway model of a screen's auditorium with the movie on its screen. Section 10. |
| **From your seat** | The first-person view from a chosen row, with the viewing angle. Section 10. |
| **Viewing angle** | Horizontal angle the picture covers from a seat: `2 × atan(picture_width / 2 / distance)`. |
| **Explainer** | A short plain-English sheet for one technical term. Section 5.8. |
| **Ambient tint** | A soft colour from the current movie's artwork, washed behind the Home headline. Section 7.3. |
| **Venue** | A cinema building (for example AMB Cinemas, Gachibowli). |
| **Screen** | One auditorium in a venue (for example AMB Screen 1). The app calls it a theatre in copy. Rankings are per screen. |

---

## 4. Information architecture

### 4.1 Navigation (Decided)

One `NavigationStack` and no tab bar. The app is a funnel: pick a movie, see the best theatres, open one, book.

- **Home** is the root.
- **Movie** and **Theatre** push onto the stack.
- **Search** opens as a full-screen cover from the search bar on Home. It slides up and Cancel closes it.
- **You** (saved theatres, history, optional details, settings) pushes from the round avatar button on Home.
- Everything else is a sheet: explainers, Book tickets, Specs and sources, How we rank, All Hyderabad screens, Cinema tech explained, About.

Back is the system back button and the edge swipe.

### 4.2 Screen map

```
Home
 ├─ Movie (push, zoom transition from the carousel card)
 │   ├─ Theatre for this movie (push)
 │   │   ├─ Book tickets (sheet)
 │   │   ├─ Specs and sources (sheet)
 │   │   └─ Explainer (sheet, from any "?")
 │   ├─ Explainer (sheet)
 │   └─ How we rank (sheet)
 ├─ Search (full-screen cover)
 │   └─ Request flow: Find this movie → progress → Movie
 └─ You (push)
     ├─ Saved theatres → Theatre (no movie context)
     ├─ Recently viewed → Movie or Theatre
     ├─ All Hyderabad screens (sheet)
     ├─ How we rank screens (sheet)
     ├─ Cinema tech explained (sheet) → Explainer
     └─ About and data sources (sheet, TMDB attribution lives here)
```

### 4.3 Deep links (Decided)

Custom scheme `screenwise://` and universal links on `https://screenwise.app/` (the domain is Open, section 16):

- `/film/{film_id}`
- `/film/{film_id}/screen/{screen_id}` (optional `?row=J`)
- `/screen/{screen_id}`
- `/request/{request_id}`

Shared links and push notifications use these.

---

## 5. Screen-by-screen specification

The prototype shows every screen below in light and dark. Measurements are in points at the default text size. Text styles refer to section 7.4, colours to 7.2.

Every screen must handle four states: **loading** (skeletons shaped like the content, never full-screen spinners), **content**, **empty** (helpful copy plus one action), **error or offline** (cached content with "Updated 2h ago" and a retry). Never show a blank screen.

### 5.1 First launch (Decided)

There is no onboarding carousel. The app opens straight on Home. The system asks for notification permission only when the user first requests a movie or turns on release reminders, with a one-line reason.

On first launch only, the first Movie page shows one dismissible tip under the section title: "The score is for this movie. The same theatre can rank differently for another one."

### 5.2 Home (Decided)

**Purpose:** say clearly what the app does, then let the user pick a movie in one tap.

**Layout, top to bottom** (side margin 20):

1. **Header row**, 44 high. Left: a glass city pill with a pin icon and "Hyderabad" (Subheadline semibold, 36 high). In v1 it opens a sheet saying more cities are coming. Right: a 36 pt round glass avatar button (the `person` symbol, or the first letter of the saved name). It pushes You. Both have 44 × 44 hit areas.
2. **Headline**: "Pick a movie." in `label` and, on a new line, "We'll pick the theatre." in `labelSecondary`, both Large Title bold. Under it, Callout in `labelSecondary`: "Every Hyderabad screen, ranked for your movie by picture, sound and size." This is how the app says it isn't a streaming service.
3. **Carousel**: one card per page, full width minus the margins, aspect 4:5, radius 28, `shadowCard`. Use horizontal paging with snapping (`ScrollView(.horizontal)` with `.scrollTargetBehavior(.paging)`), one card at a time. It must feel like the Apple TV or Netflix hero, never like a swipe-to-dismiss card stack. Each card has:
   - The artwork filling the card (rule below), under a scrim: dark over the top 22% for the chip, clear in the middle, dark over the bottom 40% for the text.
   - Top left: a glass status chip, "In cinemas" with a small green dot, or "In cinemas 18 Dec".
   - Bottom: the title in Large Title bold, white, at most 2 lines. Under it the meta line in Subheadline, for example "Hindi, English · Directed by Nitesh Tiwari".
   - A glass strip: "Best theatre for this movie" (Caption) over "{Venue} · {format}" (Headline), and a white pill button "See all ›".
   - Page dots: up to 8, white, centred 16 pt above the card's bottom edge. Inactive dots are 6 × 6 at 45% white. The active dot stretches to 18 × 6 at full white. Animate the width with a spring.
   - Tapping anywhere on the card opens Movie with a zoom transition from the card.
4. **Search bar**: 62 high, fully rounded, `card` fill, hairline border, `shadowSmall`. A magnifying glass, then "Search any movie" (Subheadline semibold) over "Telugu, Hindi, English, Tamil and more" (Footnote, `labelSecondary`). Tapping it opens Search.
5. **Footnote**, centred, Footnote in `labelSecondary`: "Screenwise doesn't stream movies. It tells you where in Hyderabad to watch them best."

**Which movies are in the carousel (Default):** up to 8. Candidates are active films released in the last 30 days or releasing in the next 120 days, in any language. Take the top 8 by anticipation (section 11.2). Order them with films in cinemas first, by anticipation, then upcoming films by release date. The page count sets the dot count.

**Auto-advance:** every 6 s, with the default spring. Pause for 9 s after any touch on the carousel. Don't auto-advance while VoiceOver is running, while Reduce Motion is on, or when Home isn't visible.

**Ambient tint:** a soft wash of the current movie's tint sits behind the header and headline (section 7.3). It cross-fades over 1 s as the page changes. This keeps a mostly white screen from feeling stark without making it dark.

**Artwork rule:** use a textless poster from TMDB (an image with no language tag), cropped to 4:5 and weighted to the top. If no textless poster exists, use the backdrop cropped to 4:5. Never place our title over a poster that already has the title painted on it. If only a titled poster exists, show it without our title and keep the chip and the glass strip.

**Empty state** (catalogue failed to load and there's no cache): a plain card, "Movies will show here once you're online.", with Retry. Search still works on any cached movies.

### 5.3 Movie (Decided)

**Purpose:** see the best theatres for this movie and why, within 10 seconds.

1. **Hero**, 520 high: the same artwork rule as the carousel, edge to edge under the status bar, with a bottom scrim. Glass buttons on top (40 pt, 44 hit area): Back on the left, Share on the right. On the image, at the bottom left: the status chip, the title (Large Title bold, white) and the meta line (Subheadline). If the original title is in another script, show it under the title in Subheadline.
   - Scrolling past the hero turns the top area into a glass bar with the title centred (Headline). Pulling down stretches the hero image.
2. **Format pills**, in a wrapping row. There's one pill per known fact, for example "IMAX", "3D", "Dolby Vision · expected" or "Scope 2.39 · est.". Each pill is Footnote semibold, 32 high, and ends with a "?" that opens the explainer for that term. Confirmed facts use the `fill` background. Expected or estimated facts use an outlined pill and say "expected" or "est.". If a fact is expected or estimated, its explainer adds: "The studio hasn't confirmed this yet. The ranking uses our best estimate and updates when they do."
3. **Section title** "Best theatres for this movie" (Title 2 bold), then Subheadline in `labelSecondary`: "Ranked by picture quality, sound and screen size for {title}."
4. **Theatre cards**, one per screen in rank order, 28 pt apart, in an Airbnb listing style:
   - An image at 16:10 with radius 22: the hall model thumbnail for this screen with this movie on its screen (section 10.6).
   - On the image: a rank badge at the top left. Rank 1 says "Best pick" in `accent`. Others say "#2", "#3" and so on in glass. At the top right, a glass heart button saves the theatre (section 5.7).
   - Under the image: the venue name (Headline) with the score at the right ("86" Headline bold plus "/100" Caption in `labelSecondary`). Then Subheadline in `labelSecondary`: "{hall} · {area} · {band}". Then the reason line in Subheadline (section 9.6). Then up to 3 fact pills. Tech pills open their explainer. Plain facts such as "75 ft screen" are outlined and don't respond to taps.
   - If any key spec is unverified, add a Footnote line with a hollow ring: "Some specs not confirmed yet".
   - The whole card opens Theatre for this movie.
5. **Opening soon card**: dashed border, radius 22. It names a known upcoming screen that could change the ranking, for example "AMB Classic Victory · IMAX with Laser", with one plain sentence. Show it only if the screen's expected opening is before the release date plus 30 days, or unknown.
6. **Footnote**: "Scores use public reports of screen size and equipment. Some specs aren't confirmed yet and are marked." It ends with a "How we rank" link that opens the score explainer.

**Re-ranking:** if the movie's format data changed since the user last opened the page, show a one-line banner for that session: "Ranking updated: the studio confirmed the IMAX version."

### 5.4 Theatre for this movie (Decided)

**Purpose:** see the hall and your view, trust the score, and book.

1. **Stage**, the top 430 pt: the live hall scene (section 10) on the `stage` background.
   - Floating glass buttons: Back on the left, Share and Heart on the right.
   - A hint line just above the segmented control: "Drag to turn · the red figure is 6 ft tall". It fades out once the user drags.
   - A glass segmented control at the bottom centre, 280 × 40: **The hall** | **From your seat**.
   - In From your seat mode, a glass readout appears at the top: "Row L · 61° of your view" (Subheadline bold) over "Immersive · about 64 ft from the screen · estimated" (Footnote). Tapping it opens the viewing angle explainer. Above the segmented control sits a horizontal row of round row chips (A, B, C and so on), 36 pt each, with the selected row in `accent`. The default row is the one nearest 60°.
2. **Sheet**: the content scrolls up over the stage as a card with a 28 pt top radius and a grabber. Once it covers the stage, the top buttons sit on a glass bar with the venue name centred.
   - The venue name (Title bold) and "{hall} · {format} · {area}" (Subheadline, `labelSecondary`).
   - **Score box** (`backgroundGrouped`, radius 18): the score in Large Title bold with "/100", then the band name (Headline) over "#1 of 9 theatres for {title}" (Subheadline, `labelSecondary`), and a "?" that opens How we rank.
   - **Stats row**: three columns split by hairlines for screen width ("75 ft"), screen shape ("Flat", with a "?") and seats ("644"). Numbers are Title 3 bold with tabular digits. Labels are Footnote.
   - **Why it suits this movie** (Title 2): 2 to 4 pros with a check in `accent`, then cons with a dash in `labelTertiary`. They come from codes (section 9.6), not free text. The first line is the screen's main reason. The second gives the picture size for this movie and its size rank in Hyderabad.
   - **The tech, in plain English** (Title 2): list rows for projection, sound and screen. Each row has a 40 pt icon tile, a title (Headline), one plain line (Subheadline), and a "?" that opens the explainer.
   - **How it scores** (Title 2): four bars in this order: Picture quality (out of 35), Sound (25), Picture size for this movie (25), Right shape and special version (15). Each shows its points, for example "31 / 35".
   - A **Specs and sources** row that opens the sheet in 5.9.
3. **Booking bar**, pinned to the bottom on glass: the movie title (Subheadline semibold) over "{venue} · {hall}" (Footnote), and the `accent` button **Book tickets** (Headline, 50 high, radius 14). It opens Book tickets (5.5).

**Theatre without a movie** (opened from Saved theatres or a `/screen/` link): the same layout. The screen shows a neutral picture in the screen's own shape. Instead of the score box, show "Best for" with up to 3 current or upcoming movies where this screen ranks in the top 3. Hide How it scores. The booking bar button says "Pick a movie" and opens Search.

**Share:** shares the deep link with an image card (1080 × 1350): the movie title, the theatre, a snapshot of the hall from the selected row, the angle and the score.

### 5.5 Book tickets (Decided)

A medium-detent sheet. It shows the kicker "Book tickets" in `accent`, the movie title (Title 2), "{venue} · {hall}", then two rows:

- **Open BookMyShow** and **Open District**. Each row has a neutral ticket icon tile, a title (Headline) and one line (Subheadline) that says what will happen: "Goes straight to this movie at this theatre" (we have a movie link), "Opens this theatre's page" (we have a venue link) or "Search for this theatre there" (no link).
- A Footnote: "Screenwise doesn't sell tickets. Prices and showtimes are on the booking app."

Use the partners' names in plain text. Don't use their logos or brand colours unless they give permission. Opening links follows section 11.6.

### 5.6 Search and request a movie (Decided)

A full-screen cover. At the top: a search field (`fill` background, radius 12, 40 high, Body text, placeholder "Movies in any language") and Cancel in `accent`. Search runs on the cached catalogue as the user types. It matches original titles, transliterations and common spellings (section 11.3).

- **Empty field:** a "Popular now" list.
- **Results:** rows with a 52 × 65 artwork thumbnail (radius 10), the title (Headline) and "{language} · {status}" (Subheadline). Tapping a row closes Search and opens the Movie.
- **No match:** a grouped card with "Not on Screenwise yet: “{query}”" (Title 2), "We'll look it up, check how it was shot, and rank every Hyderabad theatre for it. Usually a few minutes.", and the `accent` button **Find this movie**.
- **Request progress:** the card changes in place to a 3-step list with live states (waiting ring, spinning ring, filled check): "Matching the movie", "Checking how it was shot", "Ranking Hyderabad theatres". When it's ready, open the Movie and show a banner: "{title} is ready. Formats are estimated until the studio confirms." The card also has a "Notify me when it's ready" switch and the note "You can leave this screen."
- **Ambiguous match:** show up to 3 candidates (artwork, year, language) and ask "Which one?" before research starts.
- **No Indian release:** "We couldn't find a cinema release in India for this movie." with "Notify me if that changes".
- **Limits:** 5 requests per device per day. When the limit is hit: "You've requested 5 movies today. Try again tomorrow."

### 5.7 You (Decided)

An iOS grouped list in the Settings style, pushed from the avatar. The title is "You".

1. **Me card**: a 56 pt avatar circle in `accentSoft` (the person symbol, or the first letter of the name), "Add your name" or the saved name (Title 3), and "Optional. Stays on this phone." (Footnote).
2. **Saved theatres**: one row per hearted theatre, with a heart tile, the venue and "{hall} · {format} · {area}". Tapping a row opens Theatre without a movie. Swipe to delete. Empty: "Tap the heart on any theatre to save it here."
3. **Recently viewed**: the last 6 movies and theatres opened, each with artwork or a screen icon, the title and "Movie · 5 min ago". Tapping reopens it. A theatre reopens with the movie it was viewed for. Empty: "Movies and theatres you open will show up here."
4. **Your details · optional**: Name, Mobile and Email fields with right-aligned values. All are optional, lightly validated and stored on the device only in v1 (section 13.7). Nothing ever requires them.
5. **Explore**:
   - **All Hyderabad screens**: a sheet with a dense comparison table (theatre, screen size, picture tech, sound). Unconfirmed values carry an asterisk and a footnote. It also lists upcoming screens.
   - **How we rank screens**: the score explainer.
   - **Cinema tech explained**: a list of every explainer.
6. **Settings**:
   - **Appearance**: System, Light or Dark. The default is System.
   - **Release reminders**: a switch, for movies you open.
   - **About and data sources**: a sheet with how specs are sourced, the TMDB logo and notice, credits (including the three.js licence), app and data versions, a privacy summary, and Report a problem.

Hearts appear on theatre cards (Movie) and on the Theatre page. Each toggle shows a short toast at the top, "Saved. Find it under You." or "Removed from saved theatres.", with `.sensoryFeedback(.success)` when saving and `.selection` when removing.

### 5.8 Explainers (Decided)

Every technical term in the app has a "?" beside it. Tapping it opens a medium-detent sheet with:

- the kicker "Explained simply" (Footnote semibold, `accent`);
- the term (Title 2 bold);
- a small diagram when it helps (screen shape, contrast, Atmos speakers, viewing angle), drawn in SwiftUI with the tokens;
- one or two plain sentences on what it is (Body);
- a grouped box, "Why it matters", with one or two sentences;
- for screen shape on a Theatre page, a second box: "At {venue}: the screen is W × H ft. This movie plays w × h ft on it."

Use the prototype's `GLOSS` copy as the v1 text for Dolby Cinema, Dolby Vision projection, Dolby Atmos, 4K laser projection, HDR by Barco, IMAX, IMAX 1.43 scenes, 3D, EPIQ, Screen shape, Screen score and Viewing angle. Add RGB laser, PCX and DTS:X in the same voice when those appear in the data. Keep each explainer under 60 words. Store them in the String Catalog.

### 5.9 Specs and sources (sheet)

One row per spec. Each row has a provenance marker (7.6), "{label}: {value}" (Subheadline semibold), and "Sourced · {source}", "Not confirmed · {source}" or "Sources differ · {source}" (Footnote). Tapping a row expands its sources with title, publisher, date and a link that opens in an in-app Safari view. For `conflicting` fields, list every competing value with its sources. When the hall geometry is estimated, end with: "The 3D model uses the published screen size and seat count. Row spacing and hall depth are estimated." At the bottom: "See something wrong? Report a correction."

### 5.10 Report a correction

A sheet with the field (prefilled), "What should it say?", an optional source link, and an optional photo (for example a photo of the screen size plaque). It submits to `corrections`, which enters the review queue (section 11.8). Confirmation: "Thanks. We'll check it against a source before changing anything."

### 5.11 Later (v1.1, Default)

- A widget: "Best theatre for {saved movie}" with the score.
- App Intents and Spotlight: "Best theatre for Dune" opens Movie.
- A release-day notification at 9:00 local time with the top theatre, for movies with reminders on.
- "Near me" sorting on the Movie page (CoreLocation on device only).
- A "To scale" view that draws every screen's outline to one scale.
- Telugu and Hindi UI.

---

## 6. The quality bar

Bruce rejected two earlier designs for looking generic, too dark and fake. The approved bar is the Apple TV app and Airbnb. In practice:

1. **Native first.** Use system components: `NavigationStack`, sheets with detents, grouped `List` for You, menus, Liquid Glass buttons. Style them with tokens. Don't rebuild what iOS already gives you.
2. **Imagery leads.** Big artwork on Home and Movie, big 3D halls on the theatre cards. Chrome stays quiet: white or black backgrounds, one accent, no gradients on controls, no decorative borders.
3. **System type only.** SF Pro through text styles (7.4). No custom fonts, no fixed sizes, tabular digits for every number.
4. **Both themes are first class.** Design, build and snapshot-test every screen in light and dark, at the default text size and at AX3.
5. **Signature moments get extra care:** the carousel and its dots, the zoom from card to Movie, the hall scene and the fly-in to From your seat, the score box.
6. **Motion is purposeful.** Springs, never decorative bounce (7.7).
7. **Glass only for floating controls** (7.8). Content cards use flat fills.
8. **Plain English everywhere,** with an explainer for every term.
9. **Accessible.** Every screen passes the checklist in 13.6.

---

## 7. Design system

Implement these in a Swift package `DesignSystem` as semantic tokens backed by asset-catalog colours with Any, Dark and High Contrast appearances. Never use raw hex values in feature code. The prototype's CSS variables (`--bg`, `--label`, `--accent` and so on) hold the same values.

### 7.1 Theme (Decided)

Follow the system appearance by default. You → Appearance lets the user force Light or Dark. Store the choice in `UserDefaults` and apply it with `.preferredColorScheme`. Light and dark get equal care. Don't tint the whole app: colour comes from the artwork, the ambient tint and the one accent.

### 7.2 Colour tokens

| Token | Light | Dark | Use |
|---|---|---|---|
| `background` | #FFFFFF | #000000 | Screen background. |
| `backgroundGrouped` | #F6F6F7 | #0D0D0F | Grouped boxes: score box, You cards, explainer boxes, Not on Screenwise card. |
| `card` | #FFFFFF | #1C1C1E | Search bar, the selected segment, raised cards. |
| `fill` | #F1F1F3 | #2A2A2D | Pills, icon tiles, the search field. |
| `fill2` | #E8E8EB | #38383B | Grabbers, switch off, dashed borders. |
| `label` | #1D1D1F | #F5F5F7 | Primary text. |
| `labelSecondary` | #6C6C70 | #A1A1A6 | Secondary text. 5.2:1 on white, 8.2:1 on black. |
| `labelTertiary` | #A3A3A8 | #6E6E73 | Decoration only: chevrons, the "?" ring, placeholders. Never meaningful text, because it's under 4.5:1. |
| `separator` | black 9% | white 12% | Hairlines, 0.5 pt. |
| `accent` | #D6363D | #FF6369 | Book tickets, Best pick, the selected row, kickers. White on the light accent is 4.7:1. |
| `onAccent` | #FFFFFF | #1A0204 | Text and icons on `accent`. |
| `accentSoft` | accent at 10% | accent at 14% | Avatar circle, saved-theatre icon tile. |
| `glassFallback` | white 74% + blur | #1E1E20 at 72% + blur | Only where Liquid Glass isn't available. With Reduce Transparency, use solid `card`. |
| `stage` | radial #FFFFFF → #ECEEF1 → #E4E6EA | radial #232326 → #141416 → #0C0C0E | Background behind the hall scene. |
| `success` | system green | system green | The "In cinemas" dot, switch on. |

Increase Contrast: `labelSecondary` becomes #4A4A4F (light) and #C7C7CC (dark), `separator` becomes black 18% and white 22%, and glass becomes solid.

Shadows are for light mode only. `shadowCard`: 0 1 2 black 5%, 0 6 16 black 7%, 0 18 40 black 6%. `shadowSmall`: 0 1 2 black 6%, 0 4 12 black 6%. In dark mode, cards rely on fill contrast, with at most one soft black shadow.

### 7.3 Ambient tint (Decided)

Each film has `films.tint_hex`, a soft, saturated mid-tone from its artwork. Compute it on the server at ingest: run k-means (k = 5) over OKLCH pixels of the carousel artwork, ignore near-greys (chroma under 0.03), pick the cluster with the highest population × chroma, and output OKLCH L = 0.74, C = min(cluster chroma, 0.14), same hue. The default is #9FB7FF. The client never computes it, so every device shows the same colour.

Home draws it as a radial wash behind the header and headline: an ellipse 150% wide and 80% tall from the top centre, going from `mix(tint, background, 24%)` at the top, to `mix(tint, background, 9%)` at 52%, to plain `background` at 100%. In dark mode use 34% and 12%. It's 620 pt tall, sits behind the content and ignores the safe area. It cross-fades over 1 s when the page changes. Increase Contrast halves it.

### 7.4 Typography (Decided)

Use SF Pro, the system font, through SwiftUI text styles only, so Dynamic Type works everywhere. No custom fonts and no fixed point sizes in feature code. Add `.monospacedDigit()` to scores, sizes, angles and dates. Sizes below are at the default (Large) text size and match Apple's iOS type scale. Every size in the prototype maps to one of these styles.

| Use | Text style | Size | Weight |
|---|---|---|---|
| Home headline, movie titles (carousel and hero), score number, the You title | `.largeTitle` | 34 | Bold |
| Theatre name | `.title` | 28 | Bold |
| Section titles, sheet titles | `.title2` | 22 | Bold |
| Stat numbers, the name on the Me card | `.title3` | 20 | Bold or Semibold |
| Card titles, list row titles, nav titles, buttons, venue on the carousel strip | `.headline` | 17 | Semibold |
| Bullets, sheet paragraphs, settings rows, the search field | `.body` | 17 | Regular |
| Home subtitle | `.callout` | 16 | Regular |
| Secondary lines, reason lines, segmented control, row chips | `.subheadline` | 15 | Regular or Semibold |
| Pills, meta lines, stat labels, notes, grouped-list headers (uppercase), kickers | `.footnote` | 13 | Regular or Semibold |
| "/100", the small label on carousel cards, table headers | `.caption` | 12 | Regular or Medium |
| The "?" glyph | `.caption2` | 11 | Bold |

Keep the system's tracking. SF picks its Text or Display optical size by itself. The prototype adds slight negative letter-spacing at 20 pt and up only to imitate SF Display in a browser, so don't copy those values. Carousel titles wrap to at most 2 lines and may use `minimumScaleFactor(0.85)`. Nothing else scales down.

### 7.5 Spacing, radius and layout

- Base unit 4. Screen side margin 20 (16 for top bars). Gaps between sections 22 to 28.
- Radii: carousel card 28, sheet tops 28, theatre card image 22, score box 18, grouped cards 16, search bar and pills fully rounded, icon tiles 12, buttons 14, search thumbnails 10.
- Touch targets are never under 44 × 44, even where the visible control is smaller (pills 32, row chips 36, glass buttons 40).

### 7.6 Provenance marker

- `sourced`: a solid dot, 8 pt, `label`.
- `unverified` and `unknown`: a hollow ring, 8 pt, 1.5 pt stroke, `labelSecondary`.
- `conflicting`: half filled.

The marker is never the only signal. Every place that shows one also shows text ("Not confirmed", "Sources differ") or has an accessibility label.

### 7.7 Motion and haptics

- Springs: `.smooth(duration: 0.42)` for pushes and sheets (close to the prototype's `cubic-bezier(.32,.72,0,1)`), `.snappy(duration: 0.25)` for selection.
- Carousel card to Movie: `navigationTransition(.zoom(sourceID:in:))`.
- Hall scene: fly in from 1.25 times the distance over 1.1 s when the Theatre page opens. The move into From your seat takes 1.2 s, and a row change takes 0.6 s, with cubic ease-in-out. When idle, the hall sways slowly between −55° and +55° and stops at the first touch.
- Haptics: `.selection` for a row change, segment change or appearance change. `.success` when a request completes or a theatre is saved.
- Reduce Motion: cross-fade instead of zoom, no carousel auto-advance, no sway, and the camera cuts straight to its new position.

### 7.8 Materials (Liquid Glass)

Use system Liquid Glass (`.glassEffect()` and the glass button styles) only for floating controls: the city pill, the avatar, the back, share and heart buttons over images, the status chip and best-theatre strip on carousel cards, the segmented control, the seat readout, the row chips, the booking bar, and the top bar once scrolled. Content cards use flat fills. iOS 27 lets users change Liquid Glass intensity across the system, so test at both ends of that setting.

### 7.9 Iconography

SF Symbols at regular weight, sized by text style. Suggested: `mappin` (city), `person` (avatar), `magnifyingglass`, `chevron.left`, `square.and.arrow.up`, `heart` and `heart.fill`, `xmark`, `checkmark`, `minus`, `projector` (projection), `speaker.wave.3` (sound), `rectangle` (screen), `ticket` (booking), `doc.text` (sources), `chevron.right`. The "?" is a 1.3 pt ring in `labelTertiary` with a bold "?" in `labelSecondary`, as in the prototype.

### 7.10 App icon (Default)

A layered icon made in Icon Composer: a small cutaway hall seen from above and behind, a white or graphite plinth, charcoal rows, and a glowing warm picture on its screen. Provide default, dark and tinted variants. Bruce approves it before M9.

---

## 8. Data model

The backend is Postgres (Supabase, section 12). Use `snake_case`. All ids are text slugs or UUIDs as shown.

### 8.1 Core tables

```sql
create table cities (
  id text primary key,              -- 'hyderabad'
  name text not null,
  timezone text not null default 'Asia/Kolkata'
);

create table venues (
  id text primary key,              -- 'allu-cinemas'
  city_id text not null references cities(id),
  name text not null,
  area text,                        -- 'Kokapet'
  address text,
  lat double precision, lng double precision,
  venue_type text not null check (venue_type in ('multiplex','single_screen')),
  status text not null check (status in ('open','upcoming','closed','renovating')),
  opened_on date,
  expected_open text,               -- free text for upcoming ('late Nov or Dec 2026')
  operator text,                    -- 'Asian Cinemas', 'Mythri'
  district_url text, bookmyshow_url text,  -- only URLs actually found, never guessed
  updated_at timestamptz not null default now()
);

create table screens (
  id text primary key,              -- 'allu-s1-dolby'
  venue_id text not null references venues(id),
  name text not null,               -- 'Screen 1 Dolby Cinema'
  status text not null check (status in ('open','upcoming','closed','renovating')),
  -- every spec below is stored in screen_fields with provenance; these are
  -- denormalised current values for fast reads, rebuilt by a trigger
  width_ft numeric, height_ft numeric, seats int,
  tech_tier text, sound_tier text,
  brand_format text,                -- 'Dolby Cinema', 'HDR by Barco', 'IMAX with Laser', 'EPIQ', 'PCX'
  eligible_versions text[] not null default '{}',  -- {'dolby_vision'} {'imax','imax_143'} {'hdr_barco'} {'3d'}
  recliners boolean,
  rows_count int, first_row_ft numeric, row_pitch_ft numeric,  -- hall geometry if known
  confidence text not null default 'low' check (confidence in ('high','medium','low')),
  updated_at timestamptz not null default now()
);
```

### 8.2 Films

```sql
create table films (
  id text primary key,              -- 'tmdb-123456'
  tmdb_id int unique,
  title text not null,
  original_title text, original_language text,   -- ISO 639-1, 'te'
  languages text[] not null default '{}',        -- languages of the Indian release
  genres text[] not null default '{}',
  runtime_min int,
  certification_in text,
  release_date_in date,                          -- India theatrical
  release_date_status text check (release_date_status in ('confirmed','tentative','unknown')),
  poster_path text, textless_poster_path text, backdrop_path text,
  tint_hex text,                                 -- ambient tint, section 7.3
  popularity numeric,                            -- from TMDB, for ordering only
  anticipation numeric,                          -- section 11.2
  catalogue_status text not null default 'active' check (catalogue_status in ('active','hidden','no_india_release')),
  updated_at timestamptz not null default now()
);

create table film_formats (
  film_id text primary key references films(id),
  frame_ratio numeric,                 -- 2.39, 1.85, 2.00 ...
  frame_status text not null check (frame_status in ('confirmed','estimated','unknown')),
  imax text not null default 'none' check (imax in ('confirmed','expected','none')),
  imax_ratio numeric,                  -- 1.90 or 1.43 when expanded
  imax_expanded_share numeric,         -- 0..1 share of runtime in expanded ratio, if known
  dolby_vision text not null default 'none' check (dolby_vision in ('confirmed','expected','none')),
  hdr_barco text not null default 'none' check (hdr_barco in ('confirmed','expected','none')),
  three_d text not null default 'none' check (three_d in ('confirmed','expected','none')),
  checked_at timestamptz, next_check_at timestamptz
);
```

### 8.3 Provenance (Decided)

Every fact that can be wrong lives in a field table with its sources. The denormalised columns above are rebuilt from these.

```sql
create table sources (
  id uuid primary key default gen_random_uuid(),
  url text, title text, publisher text, published_on date,
  kind text check (kind in ('official','press','news','listing','user_photo','other')),
  retrieved_at timestamptz not null default now()
);

create table screen_fields (
  screen_id text references screens(id),
  field text not null,                 -- 'width_ft','height_ft','seats','projection','sound','shape',...
  value jsonb not null,                -- {"v": 75} or {"v": "Dual Christie 4K laser"}
  status text not null check (status in ('sourced','unverified','conflicting','unknown')),
  source_ids uuid[] not null default '{}',
  alternatives jsonb,                  -- for conflicting: [{"v":68,"source_ids":[...]}]
  note text,
  verified_by text,                    -- 'agent:screen-researcher@v3' or 'human:bruce'
  updated_at timestamptz not null default now(),
  primary key (screen_id, field)
);

create table film_fields ( ... same shape keyed by film_id ... );
```

Status rules:
- `sourced`: at least one named source of kind official, press or news states the value. For screen size, an official venue or manufacturer page, or two independent news reports, makes it `sourced`.
- `unverified`: only a weak source (a fan graphic, a forum post, a single listing title).
- `conflicting`: two acceptable sources disagree by more than the tolerance (screen size 3%, seats 2%, any difference for technology).
- `unknown`: no value.

Unverified values may be used in scoring but always show the hollow marker. Unknown values use the conservative defaults in section 9.

### 8.4 Rankings and listings

```sql
create table film_screen_scores (
  film_id text references films(id),
  screen_id text references screens(id),
  score_version text not null,         -- 'v2'
  total numeric not null,              -- unrounded
  size_pts numeric, tech_pts numeric, format_pts numeric, sound_pts numeric,
  picture_w_ft numeric, picture_h_ft numeric,
  low_confidence boolean not null,
  reason_code text, pros text[], cons text[],   -- codes, not prose (9.6)
  computed_at timestamptz not null default now(),
  primary key (film_id, screen_id, score_version)
);

create table listings (                -- "is this film listed at this venue?" (11.5)
  film_id text references films(id),
  venue_id text references venues(id),
  listed text not null check (listed in ('yes','no','unknown')),
  checked_at timestamptz not null,
  source_id uuid references sources(id),
  primary key (film_id, venue_id)
);
```

### 8.5 Requests, corrections and jobs

```sql
create table film_requests (
  id uuid primary key default gen_random_uuid(),
  query text not null, normalized_query text not null,
  tmdb_id int, film_id text references films(id),
  status text not null check (status in ('queued','matching','needs_choice','researching','ranking','ready','not_found','failed')),
  device_hash text not null,            -- salted hash of the App Attest key id, never raw
  push_token text,                      -- stored encrypted, deleted after notify
  created_at timestamptz default now(), updated_at timestamptz default now()
);

create table corrections (
  id uuid primary key default gen_random_uuid(),
  entity text check (entity in ('screen','venue','film')), entity_id text, field text,
  proposed jsonb, source_url text, photo_path text, note text,
  status text not null default 'new' check (status in ('new','accepted','rejected','needs_source')),
  device_hash text, created_at timestamptz default now()
);

create table agent_runs (
  id uuid primary key default gen_random_uuid(),
  kind text,            -- 'film_format','screen_research','venue_discovery','listing_check','request'
  subject_id text, model text, prompt_version text,
  status text, searches int, input_tokens int, output_tokens int, cost_usd numeric,
  output jsonb, error text,
  started_at timestamptz, finished_at timestamptz
);

create table review_queue (            -- proposed changes waiting for a human
  id uuid primary key default gen_random_uuid(),
  entity text, entity_id text, field text,
  current jsonb, proposed jsonb, evidence jsonb, agent_run_id uuid references agent_runs(id),
  decision text check (decision in ('pending','approved','rejected')) default 'pending',
  decided_by text, decided_at timestamptz
);
```

### 8.6 Client models (Swift)

Mirror the read views as `Codable` structs: `Film`, `FilmFormat`, `Venue`, `Screen`, `FieldValue<T>` (value, status, sources), `ScreenScore`, `Listing`. `FieldValue` is generic and drives the provenance marker everywhere. Put the models in a `Models` package with no UI imports.

---

## 9. The Screen Score (v2, Decided)

### 9.1 Weights

The score answers "how good is this movie's presentation on this screen?" On 19 Nov 2026 Bruce decided that picture quality and sound should count for more than raw screen size. A huge screen with ordinary projection or ordinary sound shouldn't beat a premium hall. Version 1 gave size 40 points. Version 2 gives it 25.

| Component | Points | Why this weight |
|---|---|---|
| Picture technology | 35 | Contrast, brightness and colour are where premium halls really differ. You notice a weak projector in every scene. |
| Sound | 25 | A certified, well-tuned room changes the experience. Most premium screens here have Atmos, so the spread between them is small today, but sound clearly separates them from 5.1 and 7.1 halls. |
| Picture size for this movie | 25 | Size matters and depends on the movie's shape, but it comes after quality. |
| Format match | 15 | The right screen shape, and the version made for the format (IMAX expanded scenes, a Dolby Vision grade). |

Distance, price, crowd and comfort are **not** in the score. They appear as "Why it suits this movie" lines.

Effect on the reference fixture: for *Avengers: Doomsday*, Prasads PCX (the biggest screen, with ordinary 4K laser) drops from 2nd to 3rd, and AMB Screen 1 (HDR by Barco) rises to 2nd. For a flat movie, Prasads Screen 4 (HDR by Barco) rises above PCX.

### 9.2 Picture size (0 to 25)

```
picture(screen, film_ratio):
  if screen.w / screen.h <= film_ratio: return (screen.w, screen.w / film_ratio)   # constant width
  else:                                 return (screen.h * film_ratio, screen.h)   # constant height

area = picture_w * picture_h            # sq ft
size_pts = 25 * clamp( (ln(area) - ln(300)) / (ln(4500) - ln(300)), 0, 1 )
```

The log scale reflects that the jump from 400 to 1,200 sq ft feels bigger than the jump from 3,200 to 4,000. The anchors (300 and 4,500 sq ft) are fixed for the city, so scores stay stable when screens are added. Revisit them only with a new `score_version`.

**IMAX expanded scenes:** if the screen is eligible for the movie's IMAX version, use a blended area: `area = base_area × (1 − s) + expanded_area × s`, where `s = imax_expanded_share` (0.4 if unknown), `expanded_area` uses `imax_ratio`, and `base_area` uses `frame_ratio`. If the movie's `imax` is `expected`, halve `s`. A 1.90 IMAX screen (one without `imax_143` in `eligible_versions`) shows 1.43 scenes cropped to 1.90, so use 1.90 for its `expanded_area`.

**Unknown size:** if width or height is unknown, `size_pts = 8` and the row is low confidence.

### 9.3 Picture technology (0 to 35)

| `tech_tier` | Points |
|---|---|
| `dolby_vision_dual_laser` (Dolby Cinema) | 35 |
| `imax_laser_dual_143` (IMAX with Laser, 1.43 capable, dual) | 35 |
| `hdr_barco_lightsteering` (HDR by Barco) | 31 |
| `imax_laser_190` (IMAX with Laser, 1.90) | 30 |
| `direct_view_led` (for example EPIQ LED) | 30 |
| `rgb_laser_4k` | 27 |
| `laser_4k` (laser phosphor or unspecified 4K laser) | 23 |
| `laser_2k` | 17 |
| `xenon_4k` | 16 |
| `xenon_2k` | 12 |
| `unknown` | 14 |

This order reflects broad enthusiast and critic consensus: true IMAX 1.43 with dual laser and Dolby Cinema at the top, then HDR laser systems, then standard laser. Small direct-view LED screens score high on technology, but their size points keep them honest.

### 9.4 Format match (0 to 15)

```
shape_match = |screen_ratio - film_ratio| / film_ratio <= 0.05
base = 10 if shape_match else 7
best = base
for each premium version v of the movie where v is in screen.eligible_versions:
  if film[v] == 'confirmed': best = max(best, 15)
  if film[v] == 'expected':  best = max(best, base + (15 - base) * 0.5)
format_pts = best
```

Version names to eligibility: `imax` needs `imax` (an IMAX 1.43 movie on a 1.90 IMAX screen scores 13), `dolby_vision` needs `dolby_vision`, `hdr_barco` needs `hdr_barco`, and `3d` counts only when the user asks for 3D (v1.1).

### 9.5 Sound (0 to 25)

| `sound_tier` | Points |
|---|---|
| `dolby_cinema_atmos`, `imax_12ch` | 25 |
| `atmos` | 22 |
| `dtsx`, `auro_11_1` | 18 |
| `ch_7_1` | 13 |
| `ch_5_1` | 10 |
| `unknown` | 12 |

Atmos channel counts (32, 46, 64) are shown as specs but not scored. 64 is the common maximum, and channel count alone says little about how well a room is tuned. If agents find reliable, sourced evidence of room tuning (for example a THX or Dolby certification), raise it with Bruce as a v3 change rather than scoring it ad hoc.

### 9.6 Totals, bands, confidence, explanations

- `total = tech + sound + size + format`. Store it unrounded. Show it as an integer rounded half up, once, from the unrounded total (`floor(total + 0.5)`). Never round twice, and don't use banker's rounding.
- Bands: 85 and up Reference, 75 to 84 Excellent, 65 to 74 Great, 55 to 64 Good, under 55 Standard.
- Ties (same rounded score): order by unrounded total, then by picture area, then by name.
- `low_confidence = true` if any of width, height, tech_tier or sound_tier is `unverified`, `conflicting` or `unknown`.
- The screen's `confidence` is `high` if all key fields are sourced, `medium` if one isn't, and `low` otherwise.
- **Explanations are templated, not generated.** The scorer emits a `reason_code` plus pro and con codes. The client maps them to localised strings. Examples:
  - `best_tech_black_room` → "The best picture technology in the city, in a room built to stay dark."
  - `hdr_fills_scope` → "Bright, punchy HDR on a wide screen this movie fills edge to edge."
  - `biggest_picture` → "The biggest picture in Hyderabad. Pick a centre seat."
  - `picture_size_rank` → "Picture {w} × {h} ft for this movie, #{n} for size in Hyderabad."
  - `shape_match` → "The screen matches this movie's shape, so the picture fills it."
  - `flat_screen_bands` (con) → "Flat screen, so wide scope movies get thin bars above and below."
  - `far_from_centre` (con) → "{area} is a long drive from the city centre." (only for areas over 15 km from Abids)

  Pick the main reason as the component where this screen beats the city median by the most, with ties broken in the order tech, sound, size, format. No language model ever writes user-facing ranking text.

### 9.7 Reference and parity tests

`ref/score_v2.py` is the reference. Running it prints the expected output for three fixtures: *Avengers: Doomsday* with estimated formats, a generic flat movie, and a test movie with confirmed IMAX 1.43 scenes. The third fixture adds three hypothetical screens named `TEST ...` to exercise the IMAX and unknown-size rules. They aren't real data and must never be loaded into the database. Create `fixtures/scoring/*.json` from the script's output. The server scorer (TypeScript) and the client scorer (Swift, used for offline display) must both reproduce the unrounded totals to 0.01 and the shown scores exactly. Add a CI job for that.

Expected output for *Avengers: Doomsday* (scope estimated, Dolby Vision and IMAX expected):

| Rank | Screen | Shown | Unrounded | Tech | Sound | Size | Format |
|---|---|---|---|---|---|---|---|
| 1 | Allu S1 Dolby Cinema | 90 | 90.02 | 35 | 25 | 19.0 | 11 |
| 2 | AMB S1 HDR | 79 | 78.50 | 31 | 22 | 15.5 | 10 |
| 3 | Prasads PCX | 77 | 76.62 | 23 | 22 | 24.6 | 7 |
| 4 | Prasads S4 HDR | 75 | 74.59 | 31 | 22 | 14.6 | 7 |
| 5 | Mythri Vimal | 73 | 72.74 | 23 | 22 | 17.7 | 10 |
| 6 | AAA S1 | 72 | 71.91 | 23 | 22 | 16.9 | 10 |
| 7 | Mythri Shiva Ganga | 72 | 71.66 | 23 | 22 | 16.7 | 10 |
| 8 | Sudarshan 35MM | 68 | 68.28 | 23 | 22 | 13.3 | 10 |
| 9 | ART S6 EPIQ | 66 | 65.95 | 23 | 22 | 13.9 | 7 |

AMB's unrounded total is 78.5019, so it shows 79. The JavaScript in the prototype produces the same doubles bit for bit, so your Swift and TypeScript ports should too. Compare unrounded totals to 0.01 in the parity tests.

The prototype uses exactly these numbers.

### 9.8 When scores recompute

- When any `screen_fields` or `film_formats` row for the pair changes (a database trigger enqueues a recompute).
- Nightly for all active films, as a safety net.
- Bumping `score_version` recomputes everything into new rows. The app reads only the version named in `app_config.score_version`, which is `v2` at launch.

---

## 10. Hall model and From your seat (signature feature)

### 10.1 Goal

Make screen size and seat position feel real. The user sees the whole auditorium as a cutaway model with the movie playing on its screen and turns it with a finger. Then they drop into a seat and see how much of their view the picture fills.

### 10.2 Rendering (Default)

- Use **three.js 0.160.0** in a `WKWebView`, bundled in the app under `Resources/HallScene/` (`hall.html`, `hall.js`, `three.module.js` and the addons it imports). Load it from the bundle with `loadFileURL`. It needs no network. three.js is MIT licensed, so include its licence in About → Credits.
- Start the scene code from the prototype's `Hall` class (`build`, `hallView`, `seatView`, `angle`) and its OrbitControls setup. Move it into `hall.js` as an ES module.
- SwiftUI owns everything around the canvas: the buttons, segmented control, row chips, readout and hint. The web view shows only the canvas, with a transparent background (`isOpaque = false`) over the `stage` gradient drawn in SwiftUI. Turn off web-view scrolling, zoom, link previews and text selection.
- **Bridge.** Swift calls JS with `callAsyncJavaScript`: `build(hallJSON)`, `setTheme('light' | 'dark')`, `setMode('hall' | 'seat')`, `setRow(i)` and `snapshot(w, h)`, which returns a base64 PNG. JS calls Swift through a `WKScriptMessageHandler` named `hall` with `{ready}`, `{interactionStarted}`, `{row, angle, distance}` and `{error}`.
- **`hallJSON`:** `{screen: {w, h, seats, rows?, first_row_ft?, row_pitch_ft?, recliners}, film: {ratio, imax?}, picture: {image, tint}, theme}`. `image` is a base64 JPEG, 1024 px wide, of the backdrop cropped to the movie's frame.
- **Why a web view:** the approved design is this exact scene. One renderer serves the live hall, From your seat and the card thumbnails, and WebKit's WebGL is mature on iOS. If profiling on an iPhone 12 misses the budget below, port the scene to RealityKit (a `RealityView` with a virtual camera) with the same geometry, and write the reason in `docs/decisions.md`. Don't use SceneKit, which Apple soft-deprecated at WWDC 2025.
- Pre-warm one `WKWebView` with the scene after launch, off the critical path, and reuse it.
- **Budgets:** first frame under 500 ms after the Theatre page opens with a warm web view, 60 fps while turning on iPhone 13 and newer, under 40k triangles, one 2048 shadow map.

### 10.3 Scene contents (Decided)

Units are feet. The origin is the floor at the bottom centre of the screen wall, and +z points toward the audience.

- **Plinth:** a rounded box (room width + 12) × 3 × (depth + 12), radius 1.4, with its top at y = 0. Room width = max(1.18 × screen width, screen width + 14).
- **Front floor** from the screen wall to the first row.
- **Risers:** one box per row across the full room width, `0.3 + i × rake` high and one pitch deep. Rake is 1.0 ft per row.
- **Seats:** one `InstancedMesh` of a merged rounded-box seat (back 1.7 × 2.3 × 0.4, cushion 1.7 × 0.55 × 1.6, two arms), 2.05 ft apart. Rows curve slightly (`z += x² × 0.0012`). Seats per row = floor((room width − 8) / 2.05).
- **Side walls:** extruded profiles that slope from the full room height at the screen to 6 ft at the back, so the model reads as a cutaway from behind. The front wall is full height.
- **Screen:** a black plane W × H with its bottom 3 ft above the floor. In front of it, the **picture** plane is sized to the picture for this movie (9.2) and shows the movie image, unlit (`toneMapped: false`).
- **Screen glow:** a RectAreaLight the size of the picture in the movie's tint, intensity 2.5 in light and 5 in dark.
- **Scale figure:** a 6 ft capsule-and-sphere person in `accent`, standing 36% of the picture width left of centre, 7 ft from the screen.
- **Lighting:** a hemisphere light (1.5 in light, 0.75 in dark) and one directional light from the upper left behind the audience, casting PCF soft shadows. Tone mapping ACES Filmic, exposure 1.0, sRGB output.
- **Materials:** matte standard materials, roughness 0.7 to 0.95. Colours per theme:

| Part | Light | Dark |
|---|---|---|
| Plinth | #E9E5DF | #26262A |
| Front floor | #DDD7CF | #333338 |
| Risers | #E2DDD6 | #3A3A3F |
| Walls (outer, inner) | #F4F1EC, #E6E1DA | #4A4A50, #3E3E44 |
| Seats | #3B3B40 | #5C5C63 |
| Figure | `accent` | `accent` |
| Screen mask | #141416 | #0B0B0C |

Seats are one neutral colour on purpose. We don't know the real seat colours, and the app never invents facts.

### 10.4 Cameras

- **The hall:** perspective camera, vertical FOV 30°. It looks at the room centre lowered by 12% of the room height, from azimuth 0.62 rad and polar angle 0.98 rad. Its distance fits the room's bounding sphere: `radius / sin(min(vfov, hfov) / 2)`. OrbitControls with damping 0.08, no pan, polar 0.32 to 1.32, azimuth −1.05 to 1.05, zoom from 0.55 to 1.5 times the fit distance. Idle sway as in 7.7.
- **From your seat:** eye 4.0 ft above the row's riser and 0.25 ft behind the row line, looking at a point 1.5 ft below the screen's centre, vertical FOV 52°. Controls are off. The lights dim (hemisphere −72%, directional −85%) so the picture glows.
- The readout uses the maths in 10.5, never pixels.

### 10.5 Geometry and labels

```
d(row_index) = first_row_ft + row_index * row_pitch_ft
angle_h = 2 * atan( (picture_w / 2) / d )          # degrees
angle_v = 2 * atan( (picture_h / 2) / d )
```

If the hall geometry is unknown (true for most screens), estimate it and mark it as estimated:
- `rows = clamp(round(seats / (width_ft * 0.42)), 8, 30)` (use 600 seats if the seat count is unknown)
- `first_row_ft = max(18, 0.32 * width_ft)`
- `row_pitch_ft = 5.0` if recliners, else `3.6`

Feel labels from `angle_h`: over 80° is "Very close", 50° to 80° is "Immersive", 40° to 50° is "Balanced", under 40° is "Relaxed". These thresholds are product choices, not an industry standard. Keep them in remote config so they can be tuned. The default row is the one nearest 60°. Rows are lettered from A at the front. Real halls may letter rows differently, so the readout always says "estimated" when the geometry is estimated.

### 10.6 Thumbnails

Theatre card images on the Movie page are snapshots of The hall view at 960 × 600 for each (screen, movie, theme). Render them one at a time in the pre-warmed web view after the list appears. Show a `fill` placeholder until each is ready. Cache them on disk by `screen_id + film_id + theme + scene_version`, keeping up to 200.

### 10.7 Fallback

If WebGL fails, or the phone is in Low Power Mode, show a 2D drawing in SwiftUI `Canvas` instead: the screen outline to scale, the picture for this movie inside it, a 6 ft figure, and the same readout text. The angle maths doesn't change.

### 10.8 Accessibility

The stage's label is "3D model of {venue} {hall}. The screen is W by H feet." In From your seat it's "Estimated view from row L. The picture fills 61 degrees of your view." Row chips are buttons labelled "Row L". The stage also has an adjustable action, so swiping up or down changes the row. Everything the render shows also appears as text.

---

## 11. Data pipelines (backend agents)

### 11.1 Overview

```
            ┌──────────── daily 02:00 IST ────────────┐
TMDB  ──▶  Film catalogue sync ──▶ films ──▶ Film format agent ──▶ film_formats ──┐
                                                                                   ├─▶ Scorer ──▶ film_screen_scores ──▶ app
Web   ──▶  Venue discovery (monthly) ──▶ Screen research agents (fan-out) ──▶ review_queue ──▶ screen_fields ─┘
Web   ──▶  Listing check (daily, top films) ──▶ listings
App   ──▶  Film request ──▶ TMDB match ──▶ Film format agent (priority) ──▶ Scorer ──▶ push
App   ──▶  Corrections ──▶ review_queue
```

Agents run on the **Claude API**. Default: **Claude Managed Agents** (beta header `managed-agents-2026-04-01`) for long research sessions and its scheduled deployments, and the **Messages API** with the `web_search` and `web_fetch` server tools for short jobs. Models: `claude-sonnet-5-5` for research, `claude-opus-5-5` for resolving conflicts and for the monthly audit, `claude-haiku-5-5` for matching and normalising. All three support web search. Use structured outputs (JSON schema) for every agent result. Never let an agent write to public tables directly. Agents write to `agent_runs` and `review_queue`. The Publisher (section 11.7) applies changes.

### 11.2 Film catalogue sync (daily, Decided)

Source: the TMDB API (v3), with the API key on the server only.

1. **Discover** films with an India theatrical release (region `IN`, release types theatrical and limited) and a release date from 45 days ago to 180 days ahead, for original languages `te, hi, ta, ml, kn, bn, mr, pa, gu, or, en`. For `en` and other non-Indian languages, keep a film only if it has an India release date or a popularity above the 70th percentile of that window. Check the exact parameter names against the TMDB docs at build time.
2. **Upsert** `films` with details, release dates (India), certification, posters, backdrops and genres. Also fetch a textless poster (an image with no language tag) when TMDB has one, for the carousel and the Movie hero. Compute `tint_hex` (section 7.3) for new artwork.
3. **Anticipation** (for the Home carousel and ordering): `0.6 × normalised TMDB popularity + 0.4 × normalised count of Indian news mentions in the last 14 days`. Mentions come from the format agent's research log. Use popularity alone until mention data exists.
4. Films whose release passed more than 60 days ago and that have no `yes` listings get `catalogue_status = hidden`.
5. Queue the format agent for new films and for films whose release date is within 30, 7 or 1 days, or was 1 day ago.

### 11.3 Search index

Build a server-side search over `title`, `original_title`, alternate titles from TMDB, and transliterations (generated once per film by `claude-haiku-5-5`: up to 5 Latin spellings of an Indic title, stored in `film_aliases`). The client downloads the active catalogue (about 300 to 600 films) with aliases and searches locally with a prefix and fuzzy match, so search is instant and works offline.

### 11.4 Film format agent (Decided)

**Input:** the film's title, original title, year, language, TMDB id and current `film_formats`.

**Task:** find, with sources, the frame ratio, IMAX status and ratio, Dolby Vision, HDR by Barco and 3D, for the India release.

**Evidence rules** (put these in the system prompt):
- Prefer official sources: IMAX.com and its press releases, Dolby's release lists, Barco's HDR release lists, the studio or distributor, and the film's official accounts. Then trade press (Variety, The Hollywood Reporter, Deadline, Box Office Pro, Celluloid Junkie), then major Indian outlets. Technical specs databases count as weak sources.
- `confirmed` needs one official source or two independent trade or news sources.
- `expected` means a credible report of plans (for example "will release in IMAX") without confirmation for India.
- For the frame ratio before release: if there's no source, estimate it and set `frame_status = estimated`. Big-budget Indian action films default to 2.39. Animated films default to 1.85. Otherwise use the director's last 2 films if known, else 2.39. Record the reasoning in `note`.
- Never treat a fan graphic, a forum post or a social post without a primary link as confirmation.
- Quote at most 25 words from any source in `evidence`.

**Output schema:**

```json
{
  "film_id": "tmdb-123",
  "frame_ratio": {"value": 2.39, "status": "confirmed|estimated|unknown", "sources": [{"url": "", "title": "", "publisher": "", "date": "", "quote": ""}], "note": ""},
  "imax": {"status": "confirmed|expected|none", "ratio": 1.90, "expanded_share": null, "sources": []},
  "dolby_vision": {"status": "confirmed|expected|none", "sources": []},
  "hdr_barco": {"status": "confirmed|expected|none", "sources": []},
  "three_d": {"status": "confirmed|expected|none", "sources": []},
  "india_theatrical_release": {"exists": true, "date": "2026-12-18", "sources": []},
  "confidence_notes": ""
}
```

Limits: `max_uses` of 12 searches per film, and a 3-minute budget. On `pause_turn`, continue the turn. Format changes from `expected` or `estimated` to `confirmed` auto-publish when they meet the evidence rules. Any downgrade (for example `confirmed` to `none`) goes to review.

### 11.5 Listing check (daily, Default)

**Purpose:** show "In cinemas" on cards and know which theatres are playing a current movie. v1 needs only "is this film listed at this venue at all in the next 7 days", never times or prices.

**Method:** for the top 40 current films, the agent uses `web_fetch` on the public film page of District and BookMyShow for Hyderabad, at most once per film per day, respecting `robots.txt`, and records `listed` per venue. If the fetch is blocked or the page format changes, record `unknown` and alert. Don't work around blocks.

**Legal check (Open, section 16):** Bruce should confirm this is acceptable before launch. If it's not, switch to the fallback: show all screens, mark nothing as "playing", and rely on the booking buttons.

### 11.6 Booking URLs (Decided)

The venue research agent records each venue's District and BookMyShow venue page URL if it finds one on the platform's own site. Movie-specific links are built only from a URL pattern confirmed by fetching a real page during the build. Store the pattern in `app_config.booking_url_patterns`, with a health check that verifies the links weekly. If a pattern breaks, the rows fall back to the venue page, then to the platform's home page.

Open every booking link as an `https` URL with `openURL`. If the BookMyShow or District app is installed and claims that link as a universal link, iOS opens the app on that page. Otherwise it opens in Safari. Whether their links open their apps, and on which pages, is not verified. Test it on a real iPhone with both apps installed during M8, and set each row's subtitle (5.5) from what the link really does. Never use a private app URL scheme you haven't confirmed.

### 11.7 Venue discovery and screen research (Decided)

**Discovery (initial run, then monthly):** one agent session lists every cinema venue in the Hyderabad metro area (GHMC plus Cyberabad, Rachakonda and nearby towns that Hyderabad booking pages list), using public listings, news, maps and operator sites. Output: `{name, area, operator, venue_type, status, sources}`. Merge it with existing `venues` using fuzzy name plus area matching. New venues go to review.

**Screen research (fan-out):** one research session per venue, run in parallel (for example 8 at a time). Each session:
1. Lists the venue's screens and finds, for each one, width and height (ft), shape, seats, projector make, model and tier, sound system, brand format, recliners, hall geometry if published, opening or renovation dates, and the booking URLs.
2. Records every value with its sources and a status under the rules in 8.3.
3. Notes any pros and cons that recent reviews or articles mention repeatedly (for example "PCX: complaints about side seats and legroom"), with sources, as codes from a fixed list (`steep_rake`, `side_seats_poor`, `legroom_tight`, `crowd_energy_high`, `parking_hard`, `metro_nearby`, ...).

`seed_screens.json` is the starting point. Load it first and have agents verify and extend it rather than start from nothing.

**Publisher rules:**
- New values that are `sourced` and don't contradict an existing `sourced` value publish automatically once the agent's accuracy on the gold set (11.10) is at least 95% for that field.
- Anything that changes an existing `sourced` value, any `conflicting` field and any new venue goes to `review_queue` for a human.
- Every published change writes `verified_by`.

**Audit:** monthly, `claude-opus-5-5` re-checks 10% of `sourced` fields at random and every field older than 12 months.

### 11.8 Requests (Decided)

`POST /functions/v1/request-film {query}` with an App Attest assertion:
1. Normalise the query, then check `films` and `film_aliases` (it may already exist). If it exists, return its film id.
2. Dedupe: if an open request for the same normalised query exists, attach this device and return it.
3. TMDB search. With one strong match, continue. With 2 or 3 plausible matches, set `needs_choice` and return the candidates. With none, run a short agent search to check whether the film exists under another title.
4. Run the format agent at high priority, then the scorer, then set `ready`.
5. Send an APNs push to every attached device: "{Title} is ready. Best theatre: {screen} ({score})". Delete the push tokens after sending.

The client polls `GET request/{id}` every 3 s while the screen is open and subscribes to Supabase Realtime for status changes.

### 11.9 Cost controls (Decided)

Facts: web search costs $10 per 1,000 searches plus tokens, failed searches aren't billed, web fetch has no extra charge beyond tokens, and the Message Batches API gives 50% off tokens. Check current per-token prices for the chosen models on the Claude pricing page at build time, because they aren't written into this spec.

Rough search volumes:
- Initial screen research: an expected 100 to 200 venues × 10 to 20 searches, so 1,000 to 4,000 searches ($10 to $40 in search fees).
- Daily format agent: 10 to 30 films × up to 12 searches, so at most 360 searches a day (at most $3.60 a day).
- Requests: capped at 200 a day across all users. Above that, queue until the next day.

Controls:
- Every agent run records searches, tokens and cost in `agent_runs`.
- `app_config.monthly_budget_usd` (default 150). At 80%, alert Bruce by email. At 100%, pause the non-urgent jobs (the audit and the listing check), then requests.
- Use the Batches API for the nightly format runs that aren't urgent. Use prompt caching for system prompts and tool definitions.

### 11.10 Agent evaluation (Decided)

Before turning on auto-publish, build `eval/gold.json`: 20 screens and 20 films with values checked by hand (start from the sourced fields in `seed_screens.json` and well-documented films). Run each agent against the gold set on every prompt change. Report per-field accuracy and source quality. Ship prompt changes only if accuracy doesn't drop.

### 11.11 Agent prompts

Keep the prompts in `backend/agents/prompts/*.md`, versioned (`film_format@v1`). The full starting drafts are in Appendix B.

---

## 12. Backend architecture (Default: Supabase)

### 12.1 Stack

- **Supabase**: Postgres, Row Level Security, Edge Functions (TypeScript on Deno), Storage (correction photos, share card assets), Realtime (request status) and scheduled jobs (Supabase Cron or `pg_cron`). Check current plan limits at build time.
- **Agent runner:** Edge Functions start Managed Agents sessions or Messages API calls and receive results by polling or webhook. Long sessions run on Managed Agents, not inside an Edge Function.
- **Admin app** ("Projection Room"): a small Next.js app on Vercel, behind Supabase Auth limited to Bruce's account. It shows the review queue with evidence and approve or reject, the agent runs and costs, the corrections, and a manual edit form that requires a source.

### 12.2 Public read API

Read-only Postgres views exposed through PostgREST, with RLS allowing anonymous `select` only on views:
- `v_catalogue`: active films with formats and the top screen per film.
- `v_film_ranking?film_id=`: all scores for a film with the screen and venue summary.
- `v_screen_profile?screen_id=`: the screen with every field, status and source.
- `v_screens`: every screen, for All Hyderabad screens under You.
- `v_app_config`: the score version, feature flags, thresholds and booking patterns.

The client caches responses with ETags. Images come from the TMDB image CDN at sizes chosen per view: w780 textless posters for the carousel and Movie hero, w185 for search thumbnails, w1280 backdrops for the picture on the hall screen.

### 12.3 Write endpoints (Edge Functions)

`request-film`, `request-status`, `submit-correction` and `register-push`. Each verifies App Attest, rate-limits by device hash, and validates input with zod.

### 12.4 Secrets

`ANTHROPIC_API_KEY`, `TMDB_API_KEY`, the APNs key and Supabase service keys live only in Supabase secrets and Vercel env. The iOS app holds only the public anon key and the API URL.

### 12.5 Abuse limits

5 requests per device per day, 20 corrections per device per day, and 200 requests per day globally (configurable). Use App Attest (DeviceCheck), with a soft fallback for the Simulator in debug builds only.

---

## 13. iOS app architecture

### 13.1 Targets (Decided)

- Minimum iOS **26.0**, since the Liquid Glass APIs start there. Build with the current Xcode and the iOS 27 SDK. iPhone only, though it runs on iPad in compatibility mode.
- Swift 6 with strict concurrency, SwiftUI, Observation (`@Observable`), async/await, and SwiftData for the offline cache and on-device user data.
- Bruce builds in Conductor with Claude Code, not by hand in Xcode. So keep the project generated and reproducible: use **XcodeGen** or **Tuist** (Default: XcodeGen with `project.yml`), with all settings in code. Provide `make` targets: `make bootstrap`, `make build`, `make test`, `make run` (Simulator) and `make testflight`.

### 13.2 Folder layout

```
Screenwise/
  App/                    # App entry, root NavigationStack, deep links, appearance setting
  Packages/
    Models/               # Codable models, FieldValue, no UI
    Scoring/              # Swift port of score_v2, parity tests
    Networking/           # API client, caching, ETags
    Persistence/          # SwiftData: catalogue cache, saved theatres, history, optional details
    DesignSystem/         # tokens, type styles, glass controls, Pill, ScoreBox, ProvenanceMarker, ExplainerSheet, Toast
    HallScene/            # WKWebView host, Swift bridge, thumbnail cache, Canvas fallback, geometry maths
    Features/
      Home/  Movie/  Theatre/  Booking/  Search/  You/  Explainers/
  Resources/
    HallScene/            # hall.html, hall.js, three.module.js and addons (three.js 0.160.0, MIT)
    Assets.xcassets       # colours with Dark and High Contrast variants
    Localizable.xcstrings # all copy, including explainers
  Tests/                  # unit, snapshot, UI tests
backend/
  supabase/migrations/    # SQL
  supabase/functions/     # Edge Functions
  agents/                 # runners, prompts, schemas, eval
  scoring/                # TypeScript scorer + parity tests
admin/                    # Next.js Projection Room
design/screenwise-prototype.html
ref/score_v2.py
seed_screens.json
```

### 13.3 Dependencies (Default: minimal)

Prefer Apple frameworks. Allowed: three.js 0.160.0 as vendored files in `Resources/HallScene/` (no npm at runtime, no CDN), `swift-snapshot-testing` (tests only), and `Nuke` for image caching if `AsyncImage` plus `URLCache` isn't enough. Don't add analytics SDKs, ad SDKs or Firebase.

### 13.4 State and data flow

- Each feature has an `@Observable` model that is the single source of truth for its screen. Views stay thin.
- Startup: show the SwiftData cache straight away, then refresh `v_catalogue` in the background, then diff and animate changes. Pre-warm the hall web view after the first frame.
- Rankings: fetch per movie when opened, cache them, and refresh if older than 6 hours.
- **Saved theatres** (screen ids with a saved date), **history** (the last 50 movie and theatre opens; You shows 6) and the **optional details** live in SwiftData on the device only. They're never sent to the server in v1.
- The appearance choice lives in `UserDefaults`.

### 13.5 Localization

v1 is English. All strings, including explainers, go in a String Catalog from day one. Show Indic original titles in their native script. Telugu and Hindi UI are on the v1.1 list.

### 13.6 Accessibility checklist (Decided, per screen)

- Dynamic Type up to AX5 with no clipping. Lists reflow. The carousel card grows taller at large sizes instead of truncating.
- VoiceOver: every theatre card reads as one element, for example "Rank 2, AMB Cinemas, Screen 1, Gachibowli, score 79 out of 100, Excellent. Bright, punchy HDR on a wide screen this movie fills edge to edge." The heart is a separate action ("Save theatre"). Carousel pages announce "2 of 8".
- Text contrast is at least 4.5:1, and 3:1 for 24 pt and up, in both themes. Use the tokens and don't bypass them. `labelTertiary` is never used for meaningful text.
- Respect Reduce Motion, Reduce Transparency (glass becomes solid `card`), Increase Contrast, Bold Text, and Differentiate Without Colour (provenance already uses shape).
- Every control is at least 44 × 44.

### 13.7 Privacy and analytics

- No third-party tracking. No IDFA, so no App Tracking Transparency prompt is needed.
- Optional name, mobile and email are stored only on the device in v1. They aren't sent anywhere, so they don't count as collected data on the App Privacy label. Sending them to a server later needs Bruce's decision (section 16), a privacy policy update and a new label.
- Anonymous product analytics go through our own Edge Function (`event`, `screen`, `film_id`, app version, coarse day). It's opt-out in Settings and never includes location, the optional details or precise identifiers.
- Crash reporting uses Apple's built-in reports (Xcode Organizer) in v1.
- The privacy manifest (`PrivacyInfo.xcprivacy`) declares the required-reason APIs used (for example UserDefaults).

### 13.8 Testing and performance

- Unit tests: the scoring parity fixtures, the picture maths, the angle maths and the hall geometry estimate.
- Snapshot tests: every DesignSystem component and every screen in light and dark, at the default size and AX3, plus Increase Contrast.
- UI tests: the flows Home → Movie → Theatre → Book tickets, Search → Request, and You → Saved theatre → Theatre.
- Budgets: cold start to cached content under 1.0 s on iPhone 13, Movie data shown within 400 ms on a warm network, the hall scene at 60 fps, app download under 30 MB.

---

## 14. Legal, content and App Store

### 14.1 TMDB

- TMDB's API is free for non-commercial use with attribution. Its FAQ defines a project as commercial if its primary purpose is to make money for the owner. A free app with no ads or purchases fits the non-commercial use. **If Screenwise adds a paid tier or ads, get a commercial agreement from TMDB first.**
- Attribution: show the TMDB logo (approved versions only, not modified) and the notice "This product uses the TMDB API but is not endorsed or certified by TMDB." in About. The TMDB logo must be less prominent than our own branding.
- Images: posters and backdrops come from TMDB's CDN. They're studio artwork, so use them only to identify films, never in marketing screenshots without permission.

### 14.2 Other data and brands

- Theatre specs come from public reports and are stored with citations. The 3D hall models are illustrations built from those specs and are labelled as estimated where the geometry is. Show sources in the app. Keep quotes short.
- IMAX, Dolby Cinema, Dolby Vision, Dolby Atmos, HDR by Barco, EPIQ and PCX are trademarks of their owners. Use the names in plain text to describe screens, with no logos unless permission is given.
- District and BookMyShow: plain outbound links only, with their names in plain text. Don't use their logos or brand colours without permission, and don't present Screenwise as affiliated with them.
- Listing checks (11.5) need Bruce's sign-off (Open).

### 14.3 App Store

- Category: Entertainment. Age rating: 4+ (posters may need 12+ depending on content, so check during review).
- Review notes explain that the app is read-only, has no accounts, and that rankings are editorial and computed from public data.
- The App Privacy label: location is used on device and not collected, push tokens are collected only for requested notifications and not linked to identity, and diagnostics come from Apple.
- Screenshots use the approved design with movies whose artwork we're allowed to show. Ask Bruce (section 16).

### 14.4 Disclaimers in the app

About says: "Screen specs come from public sources and our research. They can be wrong. Tap any spec to see its source, and report fixes." Every estimated value is labelled as an estimate.

---

## 15. Milestones (build in this order)

Each milestone ends with a demo on the Simulator or TestFlight and the acceptance checks passing.

**M0. Repo and tooling (0.5 day)**
- XcodeGen project, packages, the Makefile, CI (build, test, lint with SwiftLint and swift-format), and `CLAUDE.md`.
- Supabase project, migrations for section 8, and a seed loader that imports `seed_screens.json` into `venues`, `screens`, `screen_fields` and `sources`.
- Accept when `make test` passes in CI and the seed loader imports 8 venues, 10 screens and 5 upcoming entries with all provenance.

**M1. Design system and static screens (2.5 days)**
- Colour tokens with Dark and High Contrast variants, text styles, glass controls, Pill, ScoreBox, ProvenanceMarker, ExplainerSheet, Toast, and the appearance setting.
- Home (carousel, dots, ambient tint, search bar), Movie, Theatre (with a placeholder stage), Book tickets, Search, You and the explainers, built in SwiftUI with fixture data from `score_v2.py`.
- Accept when side-by-side screenshots match the prototype in light and dark (layout, type, colours, copy) at the default text size, snapshot tests pass, and the accessibility checklist passes.

**M2. Scoring and read API (1.5 days)**
- The TypeScript scorer, Edge Function triggers, the `film_screen_scores` table and the views.
- The Swift scorer and parity tests.
- Accept when both scorers match the `score_v2.py` fixtures (unrounded to 0.01, shown scores exactly), and Movie shows live data from Supabase.

**M3. Catalogue sync (1.5 days)**
- TMDB sync with textless posters and backdrops, ambient tints, the aliases job and the carousel selection rule.
- Accept when a daily run populates at least 100 films with correct India dates, the carousel shows 8 sensible movies with tints, and search finds movies by original title and by a transliteration.

**M4. Hall scene (3 days)**
- `Resources/HallScene` from the prototype's scene, the WKWebView host and bridge, The hall and From your seat, row chips, readout, haptics, theatre card thumbnails and their cache, the Canvas fallback, and the share card.
- Accept when the scene matches the prototype in both themes, the readout matches the maths for every row, it holds 60 fps on a physical iPhone 13, thumbnails appear within 2 s of opening a Movie page, and VoiceOver reads the view.

**M5. Format agent and requests (2.5 days)**
- The format agent with its schema, evidence rules, cost logging and review queue.
- The request flow end to end with push notifications.
- Accept when a requested movie goes from query to ready with a push in under 10 minutes, and the agent scores at least 90% on the gold films.

**M6. You, saved theatres, history and corrections (1.5 days)**
- Saved theatres and history in SwiftData, Theatre without a movie, All Hyderabad screens, Specs and sources, and Report a correction.
- Accept when hearts persist across launches, history reopens the right page, every seeded screen shows every field with its status and sources, and corrections reach the review queue.

**M7. Venue discovery and screen research (2.5 days)**
- The discovery run, research fan-out, publisher rules, the admin Projection Room and the gold-set eval.
- Accept when the venue list covers every Hyderabad venue that District lists, each premium screen has width, height, technology and sound with sources or explicit unknowns, and the review queue works.

**M8. Listing check and booking (1 day, after Bruce's legal sign-off)**
- Listing checks, booking URL patterns, the check of which links open the BookMyShow and District apps, and weekly health checks.
- Accept when "In cinemas" matches District for 10 sampled movies, and Book tickets opens the right app or page for 10 sampled theatres.

**M9. Polish and launch (2 days)**
- Motion pass, empty and error states, the app icon, the privacy manifest, App Store assets, and TestFlight with 10 testers.
- Accept when there are no crashes in 3 days of TestFlight, all performance budgets are met, and Bruce signs off.

---

## 16. Open questions, risks and unknowns

**Open questions for Bruce:**
1. App name and domain. "Screenwise" is a working title. Check the App Store, trademarks and the `.app` domain.
2. Is a daily listing check of public District and BookMyShow pages acceptable (11.5)? If not, use the fallback.
3. What should the optional name, mobile and email be used for? In v1 they stay on the phone and do nothing else.
4. Which Apple Developer team and bundle id should be used (for example `app.screenwise.ios`)?
5. Which movies may appear in App Store screenshots?

**Decided since version 1.0 of this spec:** light and dark following the phone (no dark-only), the Airbnb and Apple TV design direction in `design/screenwise-prototype.html`, no tab bar, and the v2 score weights.

**Risks:**
- **Thin screen data.** Many screens don't publish sizes. Mitigations: provenance markers, estimates labelled as estimates, corrections with photos, and agent audits.
- **Format data before release.** Studios confirm IMAX and Dolby versions late. The re-check schedule (T−30, T−7, T−1, T+1) and the "ranking updated" banner handle this.
- **WebGL performance on older iPhones.** The budget in 10.2, the Canvas fallback, and the RealityKit port as a plan B.
- **Managed Agents is in beta.** Wrap it behind an `AgentRunner` interface, with a Messages API implementation as the fallback.
- **Cost overrun.** The budget cap and kill switch (11.9).
- **TMDB licence** if monetised (14.1).

**What this spec verified and what it didn't (as of 19 Nov 2026):**

| Item | Status |
|---|---|
| iOS 27 is current. Liquid Glass continues, with a system intensity slider. | Verified (news coverage of WWDC 2026). |
| SceneKit is soft-deprecated, and RealityKit is the recommended native 3D path. | Verified (Apple WWDC 2025 session, Apple docs). |
| The prototype's hall scene runs in a browser WebGL context (tested in Chrome). | Verified for the prototype. Not yet profiled in a `WKWebView` on a real iPhone. Do that early in M4. |
| Every prototype font size maps to an iOS text style, and the colour tokens meet 4.5:1 for meaningful text. | Verified (audited 19 Nov 2026). |
| Claude web search costs $10 per 1,000 searches. Web fetch has no extra fee. Batches give 50% off. | Verified (Claude pricing and tool docs). |
| Managed Agents is in beta, has scheduled deployments, and supports web search and fetch. | Verified (Claude docs). |
| Model ids `claude-sonnet-5-5`, `claude-opus-5-5` and `claude-haiku-5-5` support web search. | Verified (Claude docs). |
| Per-token prices for those models. | Not verified. Check at build time. |
| The TMDB non-commercial terms and attribution text. | Verified (TMDB FAQ). |
| The TMDB commercial price. | Not verified. One secondary source mentioned a monthly fee. Ask TMDB. |
| The exact TMDB discover and image parameter names (including textless posters). | Not verified. Check the docs. |
| Hyderabad screen facts. | Mixed. See the per-field statuses in `seed_screens.json`. |
| District and BookMyShow URL patterns, and whether their links open their apps. | Not verified. Test real pages and devices during M8. |
| Supabase plan limits and prices. | Not verified. Check at build time. |

---

## Appendix A. Seed data summary

`seed_screens.json` holds 8 open venues with 10 screens and 5 upcoming entries. Key gaps for agents to fill first:

| Screen | Fields still unverified or conflicting |
|---|---|
| Prasads PCX | projection (fan graphic says dual Barco DP4K-60L), Atmos channel count |
| Prasads Screen 4 | Is it the same room as "PCX HDR by Barco"? (seat count 390 depends on this) |
| Mythri Vimal | width, height, shape, projector model |
| AAA Screen 1 | height, shape, seats (the width source says "67 feet high", which almost certainly means wide) |
| AMB Screen 1 | seats (size sources differ slightly: 62 × 26 vs 60.3 × 25.2 vs about 65 × 27) |
| ART Screen 6 | height, seats, projector model |
| Sudarshan 35MM | width, height, seats |
| Mythri Shiva Ganga | width (66 vs 68 ft), projector brand (Christie vs Barco) |
| Upcoming: AMB Classic Victory IMAX | size, ratio (1.43 or 1.90), seats, date |
| Upcoming: Mythri Ranga Dolby Cinema, AMB Hakimpet, AMB Kompally, Viswanath 70MM | almost everything |

The seed also lists screens that the design shows but whose numbers came only from an unsourced fan graphic. They're marked `unverified` and carry the hollow marker in the app until an agent finds a source.

---

## Appendix B. Agent prompt drafts (v1)

### B.1 `film_format@v1` (system prompt)

```
You research how a film will be presented in Indian cinemas. You work for Screenwise, an app that
ranks Hyderabad screens for each film. Accuracy matters more than completeness: an honest
"unknown" is better than a guess presented as fact.

For the film given by the user, find:
1. Frame aspect ratio of the standard release (for example 2.39, 1.85, 2.00).
2. IMAX: is there an IMAX release in India, is it shot for or formatted for IMAX, and what expanded
   ratio (1.90 or 1.43) and roughly what share of runtime uses it.
3. Dolby Vision (Dolby Cinema) release in India.
4. HDR by Barco release.
5. 3D release.
6. Whether an Indian theatrical release exists and its date.

Evidence rules:
- Prefer official sources (IMAX, Dolby, Barco, the studio or Indian distributor, official film
  accounts), then trade press, then major Indian outlets. Spec databases are weak sources.
- "confirmed" needs one official source or two independent trade or news sources.
- "expected" means a credible report of plans that is not confirmed for India.
- If no source gives the frame ratio before release, estimate it and set status "estimated",
  explaining the basis in "note". Defaults: big-budget Indian action 2.39; animation 1.85;
  otherwise the director's recent films; else 2.39.
- Never treat fan graphics, forum posts or unsourced social posts as confirmation.
- Quote at most 25 words from any source.
Return only JSON matching the provided schema. Every non-"unknown" value needs at least one source.
```

### B.2 `screen_research@v1` (system prompt)

```
You research one cinema venue in Hyderabad for Screenwise. You will receive the venue name,
area, and any existing data with its sources and status. Verify and extend it.

For each screen at the venue, find: screen width and height in feet, shape or aspect ratio, seat
count, projector make, model and type (for example "Christie CP4440-RGB, RGB pure laser, 4K"),
brand format (Dolby Cinema, IMAX with Laser, HDR by Barco, EPIQ, PCX, P[XL] and so on),
sound system (Dolby Atmos, IMAX 12-channel, DTS:X, 7.1, 5.1) and Atmos channel count if stated,
recliners, published hall geometry (rows, distance of first row), opening or renovation dates,
and the venue's page URLs on district.in and in.bookmyshow.com if they exist.

Rules:
- Record every value with sources and a status: sourced (named official, press or news source,
  or two independent reports for sizes), unverified (only weak sources), conflicting (acceptable
  sources disagree; list all values), unknown.
- Convert metres to feet (1 m = 3.2808 ft) and keep the original in "note".
- Do not compute or guess sizes from photos.
- Pros and cons only from repeated mentions in reviews or articles, as codes from this list:
  steep_rake, side_seats_poor, legroom_tight, crowd_energy_high, sound_too_loud, parking_hard,
  metro_nearby, food_good, cleanliness_poor. Include sources.
- Quote at most 25 words from any source.
Return only JSON matching the provided schema.
```

### B.3 Screen research output schema (abridged)

```json
{
  "venue_id": "amb-gachibowli",
  "venue_updates": {"address": {...}, "district_url": {...}, "bookmyshow_url": {...}},
  "screens": [{
    "screen_key": "Screen 1",
    "fields": {
      "width_ft": {"value": 62, "status": "sourced", "sources": [ {"url": "", "title": "", "publisher": "", "date": "", "quote": ""} ], "alternatives": [], "note": ""},
      "height_ft": {"value": 26, "status": "sourced", "sources": []},
      "seats": {"value": null, "status": "unknown", "sources": []},
      "projection": {"value": "Barco LS4K-P HDR (Lightsteering)", "tech_tier": "hdr_barco_lightsteering", "status": "sourced", "sources": []},
      "sound": {"value": "Dolby Atmos", "sound_tier": "atmos", "status": "sourced", "sources": []}
    },
    "eligible_versions": ["hdr_barco"],
    "pros": [{"code": "metro_nearby", "sources": []}],
    "cons": []
  }]
}
```

---

## Appendix C. Key copy (English)

| Key | Copy |
|---|---|
| home.headline | Pick a movie. / We'll pick the theatre. |
| home.subtitle | Every Hyderabad screen, ranked for your movie by picture, sound and size. |
| home.card.best | Best theatre for this movie |
| home.card.cta | See all |
| home.search.title | Search any movie |
| home.search.subtitle | Telugu, Hindi, English, Tamil and more |
| home.notStreaming | Screenwise doesn't stream movies. It tells you where in Hyderabad to watch them best. |
| movie.best.title | Best theatres for this movie |
| movie.best.subline | Ranked by picture quality, sound and screen size for {title}. |
| movie.unconfirmed | Some specs not confirmed yet |
| movie.estimateNote | The studio hasn't confirmed this yet. The ranking uses our best estimate and updates when they do. |
| movie.footnote | Scores use public reports of screen size and equipment. Some specs aren't confirmed yet and are marked. |
| movie.tip | The score is for this movie. The same theatre can rank differently for another one. |
| theatre.hint | Drag to turn · the red figure is 6 ft tall |
| theatre.segment.hall | The hall |
| theatre.segment.seat | From your seat |
| theatre.readout | Row {row} · {angle}° of your view |
| theatre.readout.detail | {feel} · about {d} ft from the screen · estimated |
| theatre.rank | #{n} of {total} theatres for {title} |
| theatre.why | Why it suits this movie |
| theatre.tech | The tech, in plain English |
| theatre.score.title | How it scores |
| theatre.score.subtitle | Out of 100, for this movie. |
| theatre.bars | Picture quality · Sound · Picture size for this movie · Right shape and special version |
| theatre.geometryNote | The 3D model uses the published screen size and seat count. Row spacing and hall depth are estimated. |
| book.cta | Book tickets |
| book.note | Screenwise doesn't sell tickets. Prices and showtimes are on the booking app. |
| explainer.kicker | Explained simply |
| explainer.why | Why it matters |
| search.placeholder | Movies in any language |
| search.noMatch.title | Not on Screenwise yet: “{q}” |
| search.noMatch.body | We'll look it up, check how it was shot, and rank every Hyderabad theatre for it. Usually a few minutes. |
| search.find.cta | Find this movie |
| search.steps | Matching the movie · Checking how it was shot · Ranking Hyderabad theatres |
| search.ready | {title} is ready. Formats are estimated until the studio confirms. |
| search.limit | You've requested 5 movies today. Try again tomorrow. |
| you.me.empty | Add your name |
| you.me.note | Optional. Stays on this phone. |
| you.saved.empty | Tap the heart on any theatre to save it here. |
| you.history.empty | Movies and theatres you open will show up here. |
| toast.saved | Saved. Find it under You. |
| toast.removed | Removed from saved theatres. |
| correction.thanks | Thanks. We'll check it against a source before changing anything. |
| about.tmdb | This product uses the TMDB API but is not endorsed or certified by TMDB. |

---

## Appendix D. Sources used for this spec

- Apple, *Bringing your SceneKit projects to RealityKit* and the WWDC 2025 session on SceneKit deprecation: https://developer.apple.com/documentation/realitykit/bringing-your-scenekit-projects-to-realitykit , https://developer.apple.com/videos/play/wwdc2025/288/
- MacRumors, *Here's How Liquid Glass Is Changing in iOS 27*: https://www.macrumors.com/2026/06/10/how-liquid-glass-is-changing-in-ios-27/
- Apple Newsroom, *2026 Apple Design Awards*: https://www.apple.com/newsroom/2026/06/apple-reveals-winners-of-the-2026-apple-design-awards/
- Claude docs, Web search tool: https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool
- Claude docs, Pricing: https://platform.claude.com/docs/en/about-claude/pricing
- Claude docs, Managed Agents overview: https://platform.claude.com/docs/en/managed-agents/overview
- TMDB, API FAQ and terms: https://developer.themoviedb.org/docs/faq , https://www.themoviedb.org/api-terms-of-use
- Theatre sources: listed per field in `seed_screens.json`.
