"""Cut the two rock banks along the user's red boundaries, without repainting."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ART = Path(__file__).resolve().parents[1] / "art/stage1/dano"
rocks = Image.open(ART / "rock_source.png").convert("RGBA")
boundaries = {
    "rock_left": [(0,222),(152,221),(282,226),(347,242),(380,261),(451,278),(505,306),(550,318),(573,345),(581,383),(572,437),(556,479),(528,522),(482,568),(450,595),(380,627),(348,668),(311,702),(257,738),(216,772),(161,791),(84,810),(0,819)],
    "rock_right": [(1397,174),(1262,216),(1167,251),(1032,287),(960,332),(870,389),(788,426),(720,481),(674,519),(652,562),(626,605),(621,645),(637,698),(655,765),(685,834),(723,894),(790,953),(878,980),(974,1005),(1070,1034),(1160,1059),(1248,1095),(1300,1126),(1397,1126)],
}
metadata = {}
def save_cut(name, source, boundary):
    mask = Image.new("L", (source.width * 4, source.height * 4))
    ImageDraw.Draw(mask).polygon([(x * 4, y * 4) for x, y in boundary], fill=255)
    mask = mask.resize(source.size, Image.Resampling.LANCZOS)
    result = source.copy()
    result.putalpha(mask)
    bounds = mask.getbbox()
    result.crop(bounds).save(ART / f"{name}.png")
    metadata[name] = {"source_rect": list(bounds), "boundary": boundary}

for name, boundary in boundaries.items():
    save_cut(name, rocks, boundary)
# Lower seated hair-washing group, separated from the standing woman.
original = Image.open(ART / "reference.png").convert("RGBA")
save_cut("hair_washing_women", original, [(91,484),(109,466),(124,451),(134,425),(153,419),(172,429),(183,446),(175,465),(188,476),(202,461),(221,456),(240,467),(253,459),(269,440),(290,430),(313,433),(336,446),(330,468),(347,480),(361,493),(359,517),(348,545),(334,566),(300,578),(267,576),(254,590),(210,595),(184,581),(177,557),(145,551),(111,548),(91,537),(85,520)])
(ART / "rock-crops.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("Saved rock_left.png, rock_right.png, hair_washing_women.png")
