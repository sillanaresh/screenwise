// Ambient tint from artwork (spec 7.3). Runs in the sync script, never on the phone, so
// every device shows the same colour.
//
// k-means (k = 5) over OKLCH pixels, ignoring near greys (chroma under 0.03). Pick the
// cluster with the highest population × chroma, then output OKLCH L = 0.74,
// C = min(cluster chroma, 0.14), same hue.

import jpeg from 'jpeg-js';

export const DEFAULT_TINT = '#9FB7FF';

const srgbToLinear = (c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
const linearToSrgb = (c) => (c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055);

export function rgbToOklab(r, g, b) {
  const lr = srgbToLinear(r / 255), lg = srgbToLinear(g / 255), lb = srgbToLinear(b / 255);
  const l = Math.cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb);
  const m = Math.cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb);
  const s = Math.cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb);
  return [
    0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
  ];
}

export function oklabToHex(L, a, b) {
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3;
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3;
  const s = (L - 0.0894841775 * a - 1.291485548 * b) ** 3;
  const rgb = [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
  ];
  return '#' + rgb.map((c) => Math.round(Math.min(1, Math.max(0, linearToSrgb(c))) * 255)
    .toString(16).padStart(2, '0')).join('').toUpperCase();
}

/** Tint from raw RGBA pixels. Deterministic: same pixels, same colour. */
export function tintFromPixels(data, width, height) {
  const points = [];
  const step = Math.max(1, Math.floor(Math.sqrt((width * height) / 4000)));
  for (let y = 0; y < height; y += step) {
    for (let x = 0; x < width; x += step) {
      const i = (y * width + x) * 4;
      const [L, a, b] = rgbToOklab(data[i], data[i + 1], data[i + 2]);
      if (Math.hypot(a, b) >= 0.03) points.push([L, a, b]);
    }
  }
  if (points.length < 20) return DEFAULT_TINT;

  const k = 5;
  let centres = Array.from({ length: k }, (_, j) => points[Math.floor(((j + 0.5) * points.length) / k)].slice());
  let assign = new Array(points.length).fill(0);
  for (let iter = 0; iter < 12; iter++) {
    assign = points.map((p) => {
      let best = 0, bestD = Infinity;
      centres.forEach((c, j) => {
        const d = (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2;
        if (d < bestD) { bestD = d; best = j; }
      });
      return best;
    });
    centres = centres.map((c, j) => {
      const members = points.filter((_, i) => assign[i] === j);
      if (!members.length) return c;
      return [0, 1, 2].map((d) => members.reduce((s, p) => s + p[d], 0) / members.length);
    });
  }
  let bestScore = -1, pick = centres[0];
  centres.forEach((c, j) => {
    const population = assign.filter((x) => x === j).length;
    const score = population * Math.hypot(c[1], c[2]);
    if (score > bestScore) { bestScore = score; pick = c; }
  });
  const hue = Math.atan2(pick[2], pick[1]);
  const chroma = Math.min(Math.hypot(pick[1], pick[2]), 0.14);
  return oklabToHex(0.74, chroma * Math.cos(hue), chroma * Math.sin(hue));
}

export function tintFromJPEG(bytes) {
  const img = jpeg.decode(bytes, { useTArray: true, formatAsRGBA: true });
  return tintFromPixels(img.data, img.width, img.height);
}
