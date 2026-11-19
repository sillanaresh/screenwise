# Screenwise

Pick a movie. We'll pick the theatre.

Screenwise ranks every Hyderabad cinema screen for the movie you choose, by picture quality,
sound and screen size. It shows each hall in 3D and the view from any row, explains the
technology in plain English, and sends you to BookMyShow or District to book.

- Spec: `docs/SPEC.md`
- Where the build differs from the spec, and why: `docs/decisions.md`
- Notes for coding agents: `CLAUDE.md`
- Approved design: `design/screenwise-prototype.html`

## Run it

You need Xcode 26 or later on a Mac.

```
make bootstrap   # installs XcodeGen if needed and generates the Xcode project
make run         # builds and opens the app in the iPhone simulator
make test        # runs the tests
```

## Connect the real movie list (TMDB)

Until this is done, the app shows 8 sample movies.

1. Make a free account at themoviedb.org and confirm your email.
2. Open your account settings and choose **API** (themoviedb.org/settings/api).
3. Request an API key. Choose the developer option, accept the terms, and fill in the short
   form. For the app name use "Screenwise", and describe it as a free app that lists movies
   showing in Hyderabad cinemas.
4. The API page then shows two values. Copy the long one called **API Read Access Token**.
5. Keep the token private. Add it to the GitHub repository as a secret named `TMDB_TOKEN`
   (Settings, then Secrets and variables, then Actions). Also add a repository variable named
   `CATALOGUE_SYNC_ENABLED` with the value `true`.

After that, the "Daily movie list" workflow updates `data/catalogue.json` every day at
02:00 in Hyderabad. To run it once on your Mac instead:

```
cd scripts/catalogue && npm ci && cd ../..
TMDB_TOKEN=your-token make catalogue
```

TMDB's API is free for non-commercial apps that show its attribution. If Screenwise adds ads
or a paid tier, it needs a commercial agreement with TMDB first.

## Update theatre data

Edit `data/screens.json`. Every value needs a status (`sourced`, `unverified`, `conflicting` or
`unknown`) and the ids of its sources in the `sources` list. Run `make test` to check the file.

## Mark a movie's formats

Add the movie's TMDB id to `data/film_formats.json` with its frame ratio, IMAX, Dolby Vision
and HDR status, and a source. The next daily sync uses it.
