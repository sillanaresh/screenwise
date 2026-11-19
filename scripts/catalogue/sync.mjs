#!/usr/bin/env node
// Daily movie list sync (spec 11.2, simple version). Writes data/catalogue.json.
//
//   TMDB_TOKEN=... node scripts/catalogue/sync.mjs        (API Read Access Token)
//   TMDB_API_KEY=... node scripts/catalogue/sync.mjs      (or the v3 API key)
//
// 1. Discover movies with an India theatrical release from 45 days ago to 180 days ahead,
//    in the Indian languages plus English.
// 2. Fetch details: India release date and certificate, director, genres, artwork
//    (a textless poster when TMDB has one) and Latin alternative titles for search.
// 3. Compute each movie's ambient tint from its artwork (spec 7.3). A textless poster with
//    almost no colour is dropped for the backdrop photo (see chooseArt).
// 4. Merge the hand-checked formats from data/film_formats.json. Movies without an entry get
//    the spec's default estimate: scope 2.39, or flat 1.85 for animation.
//
// TMDB's terms need the attribution shown in the app's About sheet. The key never ships in the app.

import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { tintFromJPEG, DEFAULT_TINT } from './tint.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const API = 'https://api.themoviedb.org/3';
const IMAGES = 'https://image.tmdb.org/t/p';
const LANGUAGES = ['te', 'hi', 'ta', 'ml', 'kn', 'bn', 'mr', 'pa', 'gu', 'or', 'en'];
const INDIAN = new Set(LANGUAGES.filter((l) => l !== 'en'));
const MAX_PAGES = 5;
const ALIAS_COUNTRIES = new Set(['IN', 'US', 'GB']);
// How much each language counts in Hyderabad, for ordering only (decision D-31).
const LANGUAGE_WEIGHT = { te: 1.0, hi: 0.9, en: 0.85, ta: 0.8, ml: 0.6, kn: 0.6 };
const OTHER_WEIGHT = 0.45;
const KEEP_DAYS_AFTER_RELEASE = 60;

const token = process.env.TMDB_TOKEN;
const apiKey = process.env.TMDB_API_KEY;

async function tmdb(pathname, params = {}) {
  const url = new URL(API + pathname);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, String(v));
  if (!token && apiKey) url.searchParams.set('api_key', apiKey);
  let lastError;
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      const res = await fetch(url, {
        headers: token ? { Authorization: `Bearer ${token}`, Accept: 'application/json' } : {},
        signal: AbortSignal.timeout(20000),
      });
      if (res.status === 429 || res.status >= 500) {
        lastError = new Error(`TMDB ${res.status} for ${pathname}`);
      } else if (!res.ok) {
        throw Object.assign(new Error(`TMDB ${res.status} for ${pathname}`), { fatal: true });
      } else {
        return await res.json();
      }
    } catch (e) {
      if (e.fatal) throw e;
      lastError = e;  // network reset or timeout: try again
    }
    await sleep(800 * (attempt + 1));
  }
  throw lastError;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const day = (d) => d.toISOString().slice(0, 10);
const addDays = (d, n) => new Date(d.getTime() + n * 86400000);

/** India theatrical (3) or limited (2) release, earliest date. */
export function indiaRelease(releaseDates) {
  const india = releaseDates?.results?.find((r) => r.iso_3166_1 === 'IN');
  const theatrical = (india?.release_dates || []).filter((r) => r.type === 3 || r.type === 2);
  if (!theatrical.length) return null;
  theatrical.sort((a, b) => a.release_date.localeCompare(b.release_date));
  const first = theatrical[0];
  const cert = theatrical.find((r) => r.certification)?.certification || null;
  return { date: first.release_date.slice(0, 10), certification: cert };
}

/** Turns one TMDB movie (with appended release_dates, credits, images, alternative_titles) into a catalogue film. */
export function toFilm(m, formats) {
  const release = indiaRelease(m.release_dates);
  const posters = m.images?.posters || [];
  const textless = posters.find((p) => p.iso_639_1 == null || p.iso_639_1 === 'xx');
  const director = (m.credits?.crew || []).find((c) => c.job === 'Director')?.name || null;
  const genres = (m.genres || []).map((g) => g.name);
  // Search aliases: plain English-letter titles from India, the US or the UK only.
  const plain = /^[A-Za-z0-9\s:'’.,!?&-]+$/;
  const aliases = [...new Set((m.alternative_titles?.titles || [])
    .filter((t) => ALIAS_COUNTRIES.has(t.iso_3166_1))
    .map((t) => t.title)
    .filter((t) => plain.test(t) && t !== m.title))].slice(0, 5);
  const isAnimation = genres.includes('Animation');
  const languages = (m.spoken_languages || []).map((l) => l.iso_639_1).filter((l) => LANGUAGES.includes(l));
  return {
    id: `tmdb-${m.id}`,
    tmdb_id: m.id,
    title: m.title,
    original_title: m.original_title !== m.title ? m.original_title : null,
    original_language: m.original_language,
    languages: languages.length ? languages : [m.original_language],
    genres,
    director,
    runtime_min: m.runtime || null,
    certification_in: release?.certification || null,
    release_date_in: release?.date || null,
    release_date_status: release ? 'confirmed' : 'unknown',
    poster_path: m.poster_path || null,
    textless_poster_path: textless?.file_path || null,
    backdrop_path: m.backdrop_path || null,
    tint_hex: null,
    popularity: m.popularity ?? 0,
    anticipation: null,
    aliases,
    formats: formats || {
      frame_ratio: isAnimation ? 1.85 : 2.39,
      frame_status: 'estimated',
      imax: 'none', imax_ratio: null, imax_expanded_share: null,
      dolby_vision: 'none', hdr_barco: 'none', three_d: 'none',
      note: isAnimation ? 'Default estimate for animation.' : 'Default estimate: scope 2.39.',
    },
  };
}

/**
 * Anticipation, for ordering only (spec 11.2 and decision D-31). The spec mixes TMDB popularity
 * with Indian news mentions. Without mention data, raw popularity puts Hollywood above every
 * Telugu and Hindi release. So popularity is compared within each language, then weighted by
 * how much that language is watched in Hyderabad.
 */
export function setAnticipation(films) {
  const maxByLanguage = new Map();
  for (const f of films) {
    maxByLanguage.set(f.original_language, Math.max(maxByLanguage.get(f.original_language) || 0, f.popularity || 0));
  }
  for (const f of films) {
    const max = maxByLanguage.get(f.original_language) || 1;
    const within = Math.sqrt((f.popularity || 0) / Math.max(max, 1e-9));
    const weight = LANGUAGE_WEIGHT[f.original_language] ?? OTHER_WEIGHT;
    f.anticipation = Math.round(within * weight * 1000) / 1000;
  }
  return films;
}

async function discover(language, from, to) {
  const ids = [];
  for (let page = 1; page <= MAX_PAGES; page++) {
    const data = await tmdb('/discover/movie', {
      region: 'IN',
      with_release_type: '2|3',
      'release_date.gte': from,
      'release_date.lte': to,
      with_original_language: language,
      sort_by: 'popularity.desc',
      include_adult: 'false',
      page,
    });
    ids.push(...data.results.map((r) => ({ id: r.id, popularity: r.popularity, language })));
    if (page >= data.total_pages) break;
  }
  return ids;
}

async function main() {
  if (!token && !apiKey) {
    console.error('Set TMDB_TOKEN (API Read Access Token) or TMDB_API_KEY.');
    process.exit(1);
  }
  const today = new Date();
  const from = day(addDays(today, -45));
  const to = day(addDays(today, 180));
  const formatsFile = JSON.parse(await readFile(path.join(ROOT, 'data/film_formats.json'), 'utf8'));
  const previous = JSON.parse(await readFile(path.join(ROOT, 'data/catalogue.json'), 'utf8').catch(() => '{"films":[]}'));
  const previousTints = new Map((previous.films || []).map((f) => [f.id, f]));

  const found = new Map();
  for (const language of LANGUAGES) {
    for (const r of await discover(language, from, to)) found.set(r.id, r);
  }
  console.log(`discovered ${found.size} movies`);

  const films = [];
  for (const { id } of found.values()) {
    const m = await tmdb(`/movie/${id}`, {
      append_to_response: 'release_dates,credits,images,alternative_titles',
      include_image_language: 'null,xx,en',
    });
    const film = toFilm(m, formatsFile.films?.[String(id)]?.formats);
    if (!film.release_date_in) continue;
    await chooseArt(film, previousTints.get(film.id), artTint);
    films.push(film);
  }

  // Hide movies that released more than 60 days ago.
  const cutoff = day(addDays(today, -KEEP_DAYS_AFTER_RELEASE));
  let kept = films.filter((f) => f.release_date_in >= cutoff);

  // English and other non-Indian movies stay only when popular (70th percentile of the window).
  const pops = kept.map((f) => f.popularity).sort((a, b) => a - b);
  const p70 = pops[Math.floor(pops.length * 0.7)] ?? 0;
  kept = kept.filter((f) => INDIAN.has(f.original_language) || f.popularity >= p70);

  setAnticipation(kept);
  kept.sort((a, b) => b.anticipation - a.anticipation);

  const out = { schema_version: 1, generated_at: new Date().toISOString(), source: 'tmdb', films: kept };
  await writeFile(path.join(ROOT, 'data/catalogue.json'), JSON.stringify(out, null, 2) + '\n');
  console.log(`wrote data/catalogue.json with ${kept.length} movies`);
}

/** Downloads small artwork. Returns its tint, null when it has almost no colour, or undefined on error. */
async function artTint(art) {
  try {
    const res = await fetch(`${IMAGES}/w185${art}`, { signal: AbortSignal.timeout(20000) });
    if (!res.ok) return undefined;
    return tintFromJPEG(new Uint8Array(await res.arrayBuffer()), null);
  } catch {
    return undefined;
  }
}

/**
 * Picks the card artwork and its tint (spec 5.2 and 7.3). The app uses the first of: textless
 * poster, backdrop, titled poster. A textless poster with almost no colour is usually a teaser
 * sketch that looks empty on a card, so it is dropped and the backdrop photo is used instead.
 * `old` is the movie from the last list. Its tint is reused when the artwork hasn't changed,
 * unless it is the default tint (grey artwork or a failed download), which is checked again.
 */
export async function chooseArt(film, old, tintOf) {
  const art = film.textless_poster_path || film.backdrop_path || film.poster_path;
  film.tint_art = art || null;
  if (!art) return film;
  if (old?.tint_hex && old.tint_hex !== DEFAULT_TINT && old.tint_art === art) {
    film.tint_hex = old.tint_hex;
    return film;
  }
  const tint = await tintOf(art);
  if (tint === null && art === film.textless_poster_path && film.backdrop_path) {
    film.textless_poster_path = null;
    return chooseArt(film, old, tintOf);
  }
  film.tint_hex = tint || DEFAULT_TINT;
  return film;
}

/** Puts the hand-checked formats from data/film_formats.json onto an existing catalogue. */
export function applyFormats(catalogue, formatsFile) {
  let changed = 0;
  for (const film of catalogue.films) {
    const checked = formatsFile.films?.[String(film.tmdb_id)]?.formats;
    if (checked && JSON.stringify(checked) !== JSON.stringify(film.formats)) {
      film.formats = checked;
      changed++;
    }
  }
  return changed;
}

/** `--formats-only`: apply data/film_formats.json without fetching from TMDB. No token needed. */
async function formatsOnly() {
  const file = path.join(ROOT, 'data/catalogue.json');
  const catalogue = JSON.parse(await readFile(file, 'utf8'));
  const formatsFile = JSON.parse(await readFile(path.join(ROOT, 'data/film_formats.json'), 'utf8'));
  const changed = applyFormats(catalogue, formatsFile);
  if (changed) catalogue.generated_at = new Date().toISOString();
  await writeFile(file, JSON.stringify(catalogue, null, 2) + '\n');
  console.log(`applied hand-checked formats to ${changed} movies`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const run = process.argv.includes('--formats-only') ? formatsOnly : main;
  run().catch((e) => { console.error(e); process.exit(1); });
}
