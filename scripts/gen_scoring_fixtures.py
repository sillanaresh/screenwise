"""Writes fixtures/scoring/*.json from the reference scorer in ref/score_v3.py.

Run: python3 scripts/gen_scoring_fixtures.py   (or: make fixtures)

The Swift scorer's parity tests read these files. Never edit the JSON by hand.
Regenerate it only when ref/score_v3.py changes.
"""
import importlib.util
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("score_v3", ROOT / "ref" / "score_v3.py")
ref = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ref)

DOOMSDAY = dict(ratio=2.39, versions={"dolby_vision": "expected", "imax": "expected"},
                imax={"status": "expected", "ratio": 1.90, "share": None}, spectacle=True)
FLAT = dict(ratio=1.85, versions={}, spectacle=False)
IMAX143 = dict(ratio=2.39, versions={"imax": "confirmed"},
               imax={"status": "confirmed", "ratio": 1.43, "share": 0.4}, spectacle=True)
SCOPE_DRAMA = dict(ratio=2.39, versions={}, spectacle=False)
DOLBY_VISION = dict(ratio=2.39, versions={"dolby_vision": "confirmed", "hdr_barco": "expected"}, spectacle=False)

TEST_SCREENS = dict(ref.SCREENS)
TEST_SCREENS["TEST IMAX 1.43 70x49"] = dict(w=70, h=49, tech="imax_laser_dual_143", sound="imax_12ch", eligible_versions={"imax", "imax_143"})
TEST_SCREENS["TEST IMAX 1.90 62x33"] = dict(w=62, h=33, tech="imax_laser_190", sound="imax_12ch", eligible_versions={"imax"})
TEST_SCREENS["TEST unknown size"] = dict(w=None, h=None, tech="unknown", sound="unknown", eligible_versions=set())

CASES = [
    ("doomsday", "Avengers: Doomsday (estimated scope, DV and IMAX expected)", DOOMSDAY, ref.SCREENS),
    ("flat", "A flat 1.85 film, no premium versions", FLAT, ref.SCREENS),
    ("imax143", "TEST: scope film with confirmed IMAX 1.43 scenes (40% share)", IMAX143, TEST_SCREENS),
    ("scope_drama", "A scope drama with no premium versions", SCOPE_DRAMA, TEST_SCREENS),
    ("dolby_vision", "A Dolby Vision drama, HDR by Barco expected", DOLBY_VISION, TEST_SCREENS),
]


def components(screen, film):
    """Unrounded parts, computed with the reference functions."""
    if screen.get("w") is None or screen.get("h") is None:
        size, pic_w, pic_h = ref.UNKNOWN_SIZE_POINTS, None, None
    else:
        pic_w, pic_h, area = ref.area_for(screen, film)
        size = ref.size_points(area)
    if film.get("spectacle"):
        size = size * (ref.SPECTACLE_W_SIZE / ref.W_SIZE)
    tech = ref.tech_points(screen, film) * ((ref.SPECTACLE_W_TECH / ref.W_TECH) if film.get("spectacle") else 1.0)
    return dict(tech=tech, sound=ref.SOUND[screen["sound"]], size=size,
                format=ref.format_points(screen, film), picture_w=pic_w, picture_h=pic_h)


def main():
    out_dir = ROOT / "fixtures" / "scoring"
    out_dir.mkdir(parents=True, exist_ok=True)
    for key, label, film, screens in CASES:
        rows = []
        for name, s in screens.items():
            total, _ = ref.score(s, film)
            parts = components(s, film)
            check = parts["tech"] + parts["sound"] + parts["size"] + parts["format"]
            assert abs(check - total) < 1e-9, (name, check, total)
            rows.append(dict(name=name, shown=ref.display(total), total=total, **parts))
        rows.sort(key=lambda r: -r["total"])
        for i, r in enumerate(rows, start=1):
            r["rank"] = i
        doc = dict(
            name=key,
            label=label,
            generated_by="scripts/gen_scoring_fixtures.py from ref/score_v3.py",
            film=film,
            screens=[dict(name=n, w=s["w"], h=s["h"], tech=s["tech"], sound=s["sound"],
                          eligible_versions=sorted(s["eligible_versions"])) for n, s in screens.items()],
            expected=rows,
        )
        path = out_dir / f"{key}.json"
        path.write_text(json.dumps(doc, indent=2) + "\n")
        print(f"wrote {path.relative_to(ROOT)} ({len(rows)} screens)")


if __name__ == "__main__":
    main()
