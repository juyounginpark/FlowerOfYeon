# Opening comic

`completed_reference.jpeg` and `source/` preserve the supplied images from `4cut.zip` unchanged. The separate `clouds.png` is not imported, edited or used.

`blank_narration.png` has six empty narration boxes. The built-in ImageGen tool removed the lettering; only the six paper interiors were integrated with feathered edges, preserving the original illustration and borders outside them. The exact edit prompt and interior masks are saved in `blank_narration.production.json`.

`scripts/grid_stage/opening_dialogue.gd` creates six editable Label nodes, one per narration box. It uses the exact shared `traditional_font.gd` resource used by main's stage titles, through `main_ui_style.gd`. The start prompt and E hint use that same resource. Gungsuh is preferred; GungSeo / Batang / AppleMyungjo / Noto Serif CJK KR / NanumMyeongjo provide genuine Korean traditional-font fallbacks before the engine UI fallback. On macOS, GungSeo is used when available, with AppleMyungjo as the next Korean serif fallback. Each label wraps and reduces font size only as needed to fit its safe rectangle. No letters are stretched or truncated. Text fades in as its paper finishes opening, stays legible above the paper relief, and scales with the page.

Each paper uses a tessellated mesh with a 1.15-second crumpled entrance. Once open, two held states alternate every 0.14 seconds. Irregular polygonal fold networks at two scales, soft directional relief, and fine grain approximate the attached crumpled-paper photograph. There is no TIME-driven animation, photo watermark, or regularly repeating sine-wave lighting in the idle effect.

`FloatingFog` is a full-screen ColorRect above the paper, below the start prompt and E hint. Its independent clock starts immediately on scene entry and never restarts when a cut is revealed. `opening_fog.gdshader` uses warped multi-scale noise to form soft smoke lobes and feathered wisps based on the supplied fog photograph. They drift sideways and bob vertically throughout the scene, including before the first click and during paper unfolding. Opacity is capped at 14%, with substantially lower coverage over major silhouettes. Enlarged narration masks and face/hand/human masks keep those areas clear. Masks activate only for revealed cuts; coordinates are updated on resize. The supplied cloud image remains unused.

Click/tap reveals the four panels cumulatively. After all four have fully opened, E exits to map selection. More clicks, early E presses and key-repeat events do not exit. A dedicated footer displays `E 키를 눌러 계속` in main's shared traditional font, 22px cream lettering and the game's teal/gold palette, without covering the illustration.

Narration in reading order:

1. 옛날 옛적, 게으른 이무기가 살았습니다.
2. 이무기는 매일 수행을 빼먹고 놀러다니기 바빴습니다.
3. 어느 날 이무기가 옥황상제를 찾아가 왜 자신은 용이 될 수 없냐 물었습니다.
4. 옥황상제는 그것은 네 스스로 깨달아야 한다고 말했습니다.
5. 그러자 이무기는 성을 내며 떼를 썼습니다.
6. 옥황상제는 긴 한숨을 내쉬며 말했습니다. "속세에 내려가 깨달음을 얻고 오거라." 이무기는 인간이 되어 지상에 떨어졌습니다.

Run `godot --path . --script res://tests/verify_opening.gd` for rendering and interaction checks. `--headless` skips screenshots. Captures are saved under `output/opening_verification/`.
