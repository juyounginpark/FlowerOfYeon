"""Crop original Dano pixels using hand-traced alpha masks; requires Pillow."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "art/stage1/dano"
source = Image.open(ROOT / "reference.png").convert("RGBA")
# Coordinates stay in the original 744 x 600 painting, including anchor points.
shapes = {
    "seated_women": [(534, 88), (551, 76), (573, 65), (588, 49), (608, 48), (622, 66), (620, 83), (643, 99), (663, 109), (673, 85), (697, 76), (718, 79), (731, 97), (725, 121), (740, 134), (742, 159), (726, 184), (711, 192), (697, 216), (667, 226), (635, 222), (614, 213), (592, 214), (571, 199), (551, 185), (539, 159), (544, 138), (533, 117)],
    "basket_woman": [(619, 286), (630, 276), (647, 271), (668, 278), (691, 276), (704, 286), (697, 306), (684, 313), (688, 330), (697, 346), (694, 360), (702, 380), (706, 415), (704, 444), (693, 454), (695, 470), (686, 480), (676, 477), (674, 462), (652, 458), (642, 475), (628, 478), (619, 470), (628, 447), (623, 421), (626, 394), (635, 374), (639, 349), (623, 342), (619, 326), (625, 309)],
    "stream_group": [(27, 373), (49, 350), (52, 323), (69, 305), (89, 302), (108, 316), (104, 342), (89, 355), (100, 384), (109, 413), (134, 422), (152, 420), (170, 429), (182, 446), (176, 465), (190, 478), (202, 460), (220, 457), (237, 466), (252, 458), (266, 442), (289, 431), (312, 431), (335, 445), (332, 468), (345, 477), (361, 493), (359, 515), (349, 545), (335, 563), (299, 577), (268, 576), (253, 590), (209, 594), (184, 580), (177, 556), (145, 550), (110, 548), (90, 536), (66, 528), (50, 511), (29, 502)],
    "peeking_boys": [(72, 160), (95, 153), (103, 141), (119, 137), (129, 144), (126, 124), (138, 113), (150, 118), (153, 130), (172, 151), (182, 180), (163, 172), (143, 166), (119, 169), (98, 163)],
    "upper_tree": [(461, 0), (556, 0), (569, 13), (576, 26), (588, 29), (583, 38), (594, 43), (586, 51), (598, 57), (581, 65), (572, 83), (564, 101), (541, 110), (527, 93), (513, 75), (498, 49), (490, 29), (474, 17), (455, 23), (442, 12)],
    "swing_woman": [(428, 108), (439, 101), (447, 109), (447, 128), (455, 128), (462, 123), (478, 128), (489, 137), (494, 151), (510, 163), (520, 171), (530, 191), (539, 217), (529, 235), (517, 244), (513, 263), (510, 288), (504, 302), (512, 308), (504, 318), (486, 318), (473, 308), (471, 286), (460, 265), (449, 244), (444, 224), (439, 201), (442, 181), (434, 168), (430, 146), (425, 126)],
}
metadata = {}
for name, polygon in shapes.items():
    # Supersample only the mask, keeping all colour pixels from the source.
    scale = 4
    mask = Image.new("L", (source.width * scale, source.height * scale))
    draw = ImageDraw.Draw(mask)
    draw.polygon([(x * scale, y * scale) for x, y in polygon], fill=255)
    if name == "swing_woman":
        draw.line([(447 * scale, 0), (448 * scale, 311 * scale)], fill=255, width=2 * scale)
        draw.line([(491 * scale, 0), (502 * scale, 310 * scale)], fill=255, width=2 * scale)
    mask = mask.resize(source.size, Image.Resampling.LANCZOS)
    rgba = source.copy()
    rgba.putalpha(mask)
    bounds = mask.getbbox()
    rgba.crop(bounds).save(ROOT / f"{name}.png")
    metadata[name] = {"source_rect": list(bounds), "polygon": polygon}
(ROOT / "crops.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Saved {len(metadata)} original-pixel RGBA crops")
