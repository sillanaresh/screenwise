// Offline tests for the sync script: run with `npm test` in scripts/catalogue.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import jpeg from 'jpeg-js';
import { indiaRelease, toFilm, setAnticipation } from './sync.mjs';
import { tintFromPixels, tintFromJPEG, oklabToHex, rgbToOklab, DEFAULT_TINT } from './tint.mjs';

const movie = {
  id: 123,
  title: 'Example',
  original_title: 'ఉదాహరణ',
  original_language: 'te',
  genres: [{ id: 28, name: 'Action' }],
  runtime: 160,
  popularity: 42,
  poster_path: '/titled.jpg',
  backdrop_path: '/backdrop.jpg',
  spoken_languages: [{ iso_639_1: 'te' }, { iso_639_1: 'hi' }],
  release_dates: { results: [
    { iso_3166_1: 'US', release_dates: [{ type: 3, release_date: '2026-12-01T00:00:00.000Z', certification: 'R' }] },
    { iso_3166_1: 'IN', release_dates: [
      { type: 4, release_date: '2027-01-30T00:00:00.000Z', certification: '' },
      { type: 3, release_date: '2026-12-18T00:00:00.000Z', certification: 'UA 13+' },
    ] },
  ] },
  credits: { crew: [{ job: 'Writer', name: 'A' }, { job: 'Director', name: 'B' }] },
  images: { posters: [{ iso_639_1: 'en', file_path: '/en.jpg' }, { iso_639_1: null, file_path: '/textless.jpg' }] },
  alternative_titles: { titles: [
    { iso_3166_1: 'IN', title: 'Udaharana' }, { iso_3166_1: 'IN', title: 'ఉదాహరణ' },
    { iso_3166_1: 'US', title: 'Example' }, { iso_3166_1: 'TR', title: 'Ornek Film' },
    { iso_3166_1: 'GB', title: 'Exámple Two' },
  ] },
};

test('indiaRelease uses the India theatrical date and certificate', () => {
  assert.deepEqual(indiaRelease(movie.release_dates), { date: '2026-12-18', certification: 'UA 13+' });
  assert.equal(indiaRelease({ results: [] }), null);
});

test('toFilm maps TMDB fields to the catalogue schema', () => {
  const f = toFilm(movie);
  assert.equal(f.id, 'tmdb-123');
  assert.equal(f.release_date_in, '2026-12-18');
  assert.equal(f.director, 'B');
  assert.equal(f.textless_poster_path, '/textless.jpg');
  assert.deepEqual(f.languages, ['te', 'hi']);
  assert.deepEqual(f.aliases, ['Udaharana']);
  assert.equal(f.formats.frame_ratio, 2.39);
  assert.equal(f.formats.frame_status, 'estimated');
});

test('toFilm estimates flat 1.85 for animation and keeps hand-checked formats', () => {
  const anim = toFilm({ ...movie, genres: [{ name: 'Animation' }] });
  assert.equal(anim.formats.frame_ratio, 1.85);
  const checked = { frame_ratio: 2.39, frame_status: 'confirmed', imax: 'confirmed', imax_ratio: 1.43 };
  assert.equal(toFilm(movie, checked).formats.imax, 'confirmed');
});

test('tint picks the main saturated colour at L 0.74', () => {
  const w = 40, h = 40, data = new Uint8Array(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    const orange = i % 4 !== 0;
    data.set(orange ? [230, 120, 30, 255] : [128, 128, 128, 255], i * 4);
  }
  const hex = tintFromPixels(data, w, h);
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
  assert.ok(r > g && g > b, `expected a warm tint, got ${hex}`);
  const [L] = rgbToOklab(r, g, b);
  assert.ok(Math.abs(L - 0.74) < 0.02, `lightness ${L}`);
});

test('tint falls back to the default for grey artwork', () => {
  const data = new Uint8Array(30 * 30 * 4).fill(120);
  assert.equal(tintFromPixels(data, 30, 30), DEFAULT_TINT);
});

test('tint decodes a JPEG', () => {
  const w = 32, h = 32, data = Buffer.alloc(w * h * 4);
  for (let i = 0; i < w * h; i++) data.set([40, 120, 220, 255], i * 4);
  const encoded = jpeg.encode({ data, width: w, height: h }, 90);
  const hex = tintFromJPEG(new Uint8Array(encoded.data));
  const [r, , b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
  assert.ok(b > r, `expected a blue tint, got ${hex}`);
});

test('OKLab round trip', () => {
  const [L, a, b] = rgbToOklab(159, 183, 255);
  assert.equal(oklabToHex(L, a, b), '#9FB7FF');
});

test('anticipation compares popularity within each language, weighted for Hyderabad', () => {
  const films = setAnticipation([
    { original_language: 'en', popularity: 300 },
    { original_language: 'en', popularity: 30 },
    { original_language: 'te', popularity: 40 },
    { original_language: 'or', popularity: 5 },
  ]);
  assert.equal(films[2].anticipation, 1);      // top Telugu movie
  assert.equal(films[0].anticipation, 0.85);   // top English movie
  assert.ok(films[1].anticipation < films[0].anticipation);
  assert.equal(films[3].anticipation, 0.45);   // top Odia movie
});
