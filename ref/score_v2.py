"""Reference implementation of the Screenwise Screen Score v2. Run: python3 score_v2.py

v2 weights (Decided by the product owner, 19 Nov 2026): picture quality and sound count for more
than raw screen size, so a huge screen with ordinary projection can't beat a premium hall.
  Picture technology 35 · Sound 25 · Picture size 25 · Format match 15 = 100
"""
import math

A_MIN, A_MAX = 300.0, 4500.0   # sq ft anchors for the size curve (fixed, city-wide)

W_TECH, W_SOUND, W_SIZE, W_FORMAT = 35, 25, 25, 15

TECH = {  # picture technology tier -> points out of 35
    "dolby_vision_dual_laser": 35, "imax_laser_dual_143": 35, "hdr_barco_lightsteering": 31,
    "imax_laser_190": 30, "direct_view_led": 30, "rgb_laser_4k": 27, "laser_4k": 23,
    "laser_2k": 17, "xenon_4k": 16, "xenon_2k": 12, "unknown": 14,
}
SOUND = {  # sound system tier -> points out of 25
    "dolby_cinema_atmos": 25, "imax_12ch": 25, "atmos": 22, "dtsx": 18, "auro_11_1": 18,
    "ch_7_1": 13, "ch_5_1": 10, "unknown": 12}
UNKNOWN_SIZE_POINTS = 8.0   # unknown size: conservative, low confidence

def picture(screen_w, screen_h, film_ratio):
    """Largest film-shaped rectangle that fits the screen (constant width or height)."""
    if screen_w / screen_h <= film_ratio:
        return screen_w, screen_w / film_ratio
    return screen_h * film_ratio, screen_h

def size_points(area):
    x = (math.log(area) - math.log(A_MIN)) / (math.log(A_MAX) - math.log(A_MIN))
    return W_SIZE * min(1.0, max(0.0, x))

def format_points(screen, film):
    if screen.get("w") and screen.get("h"):
        shape_match = abs((screen["w"] / screen["h"]) - film["ratio"]) / film["ratio"] <= 0.05
    else:
        shape_match = False
    base = 10 if shape_match else 7
    best = base
    for version, status in film["versions"].items():      # e.g. {"dolby_vision": "expected"}
        ceiling = None
        if version == "imax":
            wants_143 = film.get("imax", {}).get("ratio", 1.90) < 1.89
            if "imax_143" in screen["eligible_versions"]:
                ceiling = 15
            elif "imax" in screen["eligible_versions"]:
                ceiling = 13 if wants_143 else 15      # 1.43 film on a 1.90 IMAX screen
        elif version in screen["eligible_versions"]:
            ceiling = 15
        if ceiling is None:
            continue
        if status == "confirmed":
            best = max(best, ceiling)
        elif status == "expected":
            best = max(best, base + (ceiling - base) * 0.5)
    return best

def area_for(screen, film):
    """Picture area for this film, blending IMAX expanded scenes when the screen gets that version."""
    w, h = picture(screen["w"], screen["h"], film["ratio"])
    area = w * h
    imax = film.get("imax")  # {"status": "confirmed"|"expected", "ratio": 1.90|1.43, "share": 0.4|None}
    if imax and ("imax" in screen["eligible_versions"] or "imax_143" in screen["eligible_versions"]):
        ratio = imax["ratio"]
        if ratio < 1.89 and "imax_143" not in screen["eligible_versions"]:
            ratio = 1.90                       # a 1.90 IMAX screen shows 1.43 scenes cropped to 1.90
        ew, eh = picture(screen["w"], screen["h"], ratio)
        share = imax.get("share") if imax.get("share") is not None else 0.4
        if imax["status"] == "expected":
            share = share / 2
        area = area * (1 - share) + ew * eh * share
    return w, h, area

def score(screen, film):
    if screen.get("w") is None or screen.get("h") is None:
        w = h = None
        s = UNKNOWN_SIZE_POINTS
    else:
        w, h, area = area_for(screen, film)
        s = size_points(area)
    t = TECH[screen["tech"]]
    f = format_points(screen, film)
    a = SOUND[screen["sound"]]
    pic = (round(w, 1), round(h, 1)) if w is not None else None
    total = s + t + f + a                      # keep unrounded; round only for display
    return total, dict(size=round(s, 1), tech=t, format=round(f, 1), sound=a, pic=pic)

def display(total):
    """Shown score: round half up, once, from the unrounded total. Never round twice."""
    return int(math.floor(total + 0.5))

SCREENS = {
    "Allu S1 Dolby Cinema": dict(w=75, h=40.5, tech="dolby_vision_dual_laser", sound="dolby_cinema_atmos", eligible_versions={"dolby_vision"}),
    "Prasads PCX":          dict(w=101.6, h=64, tech="laser_4k", sound="atmos", eligible_versions=set()),
    "AMB S1 HDR":           dict(w=62, h=26, tech="hdr_barco_lightsteering", sound="atmos", eligible_versions={"hdr_barco"}),
    "Mythri Vimal":         dict(w=70, h=29.3, tech="laser_4k", sound="atmos", eligible_versions=set()),
    "Prasads S4 HDR":       dict(w=59, h=31, tech="hdr_barco_lightsteering", sound="atmos", eligible_versions={"hdr_barco"}),
    "AAA S1":               dict(w=67, h=28, tech="laser_4k", sound="atmos", eligible_versions=set()),
    "Mythri Shiva Ganga":   dict(w=66, h=29, tech="laser_4k", sound="atmos", eligible_versions=set()),
    "Sudarshan 35MM":       dict(w=55, h=23, tech="laser_4k", sound="atmos", eligible_versions=set()),
    "ART S6 EPIQ":          dict(w=57, h=30, tech="laser_4k", sound="atmos", eligible_versions=set()),
}

if __name__ == "__main__":
    doomsday = dict(ratio=2.39, versions={"dolby_vision": "expected", "imax": "expected"},
                    imax={"status": "expected", "ratio": 1.90, "share": None})
    flat_film = dict(ratio=1.85, versions={})
    imax_film = dict(ratio=2.39, versions={"imax": "confirmed"},
                     imax={"status": "confirmed", "ratio": 1.43, "share": 0.4})
    # Hypothetical screens to exercise IMAX and unknown-size rules (not real data):
    TEST_SCREENS = dict(SCREENS)
    TEST_SCREENS["TEST IMAX 1.43 70x49"] = dict(w=70, h=49, tech="imax_laser_dual_143", sound="imax_12ch", eligible_versions={"imax", "imax_143"})
    TEST_SCREENS["TEST IMAX 1.90 62x33"] = dict(w=62, h=33, tech="imax_laser_190", sound="imax_12ch", eligible_versions={"imax"})
    TEST_SCREENS["TEST unknown size"] = dict(w=None, h=None, tech="unknown", sound="unknown", eligible_versions=set())
    cases = [("Avengers: Doomsday (estimated scope, DV and IMAX expected)", doomsday, SCREENS),
             ("A flat 1.85 film, no premium versions", flat_film, SCREENS),
             ("TEST: scope film with confirmed IMAX 1.43 scenes (40% share)", imax_film, TEST_SCREENS)]
    for label, film, screens in cases:
        print("\n" + label)
        rows = sorted(((score(s, film), n) for n, s in screens.items()), key=lambda r: -r[0][0])
        for (total, parts), name in rows:
            print(f"  {display(total):>3}  ({total:6.2f})  {name:<22} {parts}")
