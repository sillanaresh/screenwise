# App Store listing

Text to paste into App Store Connect. Character limits are Apple's.

## App information

- **Name** (30): Screenwise: Cinemas (the App Store Connect record, 20 Nov 2026)
  - "Screenwise" alone is taken on the store by an unrelated utility app.
  - The name under the icon stays "Screenwise" (`CFBundleDisplayName`). Apple allows a shorter
    home screen name when it matches the start of the store name.
- **Subtitle** (30): The best screen for each movie
- **Category:** Entertainment. Secondary: Lifestyle.
- **Bundle ID:** app.screenwise.ios
- **SKU:** screenwise-ios
- **Primary language:** English (U.K.)
- **Content rights:** Yes, it shows third-party content: movie titles, pictures and details
  from TMDB, used under TMDB's API terms. The app shows the TMDB notice in About.

## URLs

- **Support URL:** https://sillanaresh.github.io/screenwise/
- **Marketing URL:** https://sillanaresh.github.io/screenwise/
- **Privacy Policy URL:** https://sillanaresh.github.io/screenwise/privacy.html

## Promotional text (170)

Hyderabad's top cinemas, ranked for the movie you want to see. Find the biggest picture, the
best projector and the best sound before you book.

## Description (4000)

Pick a movie. We'll pick the theatre.

Screenwise ranks Hyderabad's top cinema screens for the movie you choose, by picture quality,
sound and screen size. The same theatre can rank differently for another movie, because every
movie is shot in its own shape and format.

SEE THE HALL BEFORE YOU GO
Turn each hall around in 3D and switch to "From your seat" to see how big the picture looks
from the row you pick.

A SCORE FOR EACH MOVIE
Every screen gets a score out of 100 for each movie, from four things: picture technology,
sound, picture size and how well the screen fits the movie. Tap any score to see why.

HONEST DETAILS
Every spec shows where it came from. Anything we haven't confirmed is marked "Not confirmed",
and sizes we don't know show a question mark. We never guess a number.

PREMIUM FORMATS EXPLAINED
Dolby Cinema, IMAX, EPIQ, PXL, laser projection, Dolby Atmos and more, each in plain words.

BOOK IN ONE TAP
When you've picked a theatre, Book tickets opens BookMyShow or District.

UPDATED OFTEN
The movie list updates every day, with Telugu, Hindi, English, Tamil and other releases.
Theatres are checked every week or two. See something wrong? Report a correction from any
theatre page.

No accounts, no ads and no tracking.

Movie data and pictures come from TMDB. This product uses the TMDB API but is not endorsed or
certified by TMDB. Screenwise doesn't sell tickets.

## Keywords (100)

hyderabad,theatre,theater,movie,screen,seat,laser,sound,big screen,telugu,hindi,tollywood,4k

Words already in the name ("Screenwise", "Cinemas") count for search, so they are not
repeated here. Brand names like IMAX, Dolby, PVR and INOX are left out on purpose. Apple can reject
keywords that use other companies' trademarks.

## What's New (first version)

First release. Hyderabad's top cinemas, ranked for every movie.

## App Privacy (the privacy questions in App Store Connect)

- **Do you or your third-party partners collect data from this app?** No.
- The label then shows "Data Not Collected". Feedback is sent from the user's own Mail app, so
  the app itself collects nothing. Saved theatres, history and details stay on the phone.

## Age rating

Answer "None" to every content question. There is no user-generated content inside the app,
and it has no unrestricted web browsing; booking links open other apps or Safari. Expected
rating: 4+.

## Export compliance

Already answered in Info.plist (`ITSAppUsesNonExemptEncryption` is false). The app only uses
HTTPS through Apple's system networking.

## App Review notes

No sign-in is needed. The app reads two public data files and TMDB images. To try it: open
any movie on Home, tap a theatre, then switch between "The hall" and "From your seat".

## Screenshots

6.9 inch iPhone, 1320 × 2868 JPEG, in `design/app-store/` (made with `make screenshots`):
1. Home
2. Movie page with the ranking
3. Theatre page with the 3D hall
4. From your seat
5. A plain-words explainer
