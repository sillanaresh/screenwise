"""Generates the colour tokens in Screenwise/Resources/Assets.xcassets/Colors (spec 7.2).

Run: python3 scripts/gen_colors.py   (or: make colors)

This table is the source of truth for colours. Each token has light, dark, and the
Increase Contrast versions of both. Feature code uses `Color.sw.<token>`, never hex.
"""
import json
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Screenwise" / "Resources" / "Assets.xcassets" / "Colors"

# token: (light, dark, light high contrast, dark high contrast). Colours are (hex, alpha).
TOKENS = {
    "background": (("FFFFFF", 1), ("000000", 1), None, None),
    "backgroundGrouped": (("F6F6F7", 1), ("0D0D0F", 1), None, None),
    "card": (("FFFFFF", 1), ("1C1C1E", 1), None, None),
    "fill": (("F1F1F3", 1), ("2A2A2D", 1), None, None),
    "fill2": (("E8E8EB", 1), ("38383B", 1), None, None),
    "label": (("1D1D1F", 1), ("F5F5F7", 1), None, None),
    "labelSecondary": (("6C6C70", 1), ("A1A1A6", 1), ("4A4A4F", 1), ("C7C7CC", 1)),
    "labelTertiary": (("A3A3A8", 1), ("6E6E73", 1), None, None),
    "separator": (("000000", 0.09), ("FFFFFF", 0.12), ("000000", 0.18), ("FFFFFF", 0.22)),
    "accent": (("D6363D", 1), ("FF6369", 1), None, None),
    "onAccent": (("FFFFFF", 1), ("1A0204", 1), None, None),
    "accentSoft": (("D6363D", 0.10), ("FF6369", 0.14), None, None),
    "glassFallback": (("FFFFFF", 0.74), ("1E1E20", 0.72), None, None),
    # Stage: a radial gradient behind the hall scene, centre to edge.
    "stageCenter": (("FFFFFF", 1), ("232326", 1), None, None),
    "stageMid": (("ECEEF1", 1), ("141416", 1), None, None),
    "stageEdge": (("E4E6EA", 1), ("0C0C0E", 1), None, None),
}


def comp(hex_, alpha):
    r, g, b = (int(hex_[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return {"color-space": "srgb", "components": {
        "red": f"{r:.3f}", "green": f"{g:.3f}", "blue": f"{b:.3f}", "alpha": f"{alpha:.3f}"}}


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    (OUT / "Contents.json").write_text(json.dumps(
        {"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": True}}, indent=2))
    for name, (light, dark, light_hc, dark_hc) in TOKENS.items():
        light_hc = light_hc or light
        dark_hc = dark_hc or dark
        colors = [
            {"idiom": "universal", "color": comp(*light)},
            {"idiom": "universal", "appearances": [{"appearance": "luminosity", "value": "dark"}],
             "color": comp(*dark)},
            {"idiom": "universal", "appearances": [{"appearance": "contrast", "value": "high"}],
             "color": comp(*light_hc)},
            {"idiom": "universal", "appearances": [{"appearance": "luminosity", "value": "dark"},
                                                   {"appearance": "contrast", "value": "high"}],
             "color": comp(*dark_hc)},
        ]
        d = OUT / f"{name}.colorset"
        d.mkdir()
        (d / "Contents.json").write_text(json.dumps(
            {"colors": colors, "info": {"author": "xcode", "version": 1}}, indent=2))
    print(f"wrote {len(TOKENS)} colour tokens to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
