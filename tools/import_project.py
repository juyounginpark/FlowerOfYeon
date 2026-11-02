"""Import in the editor with dummy drivers; never enter the game scene tree."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
project = root / 'project.godot'
original = project.read_text(encoding='utf-8')
# Tracked .import files can point to an absent cache on a fresh checkout.
# Bootstrap the configured project font before the editor tries to use it.
font_lines = [line for line in original.splitlines(True) if line.startswith('theme/custom_font=')]
args = [sys.argv[1], '--headless', '--rendering-driver', 'dummy', '--audio-driver', 'Dummy',
        '--path', str(root), '--editor', '--import']
try:
    bootstrap = original
    for line in font_lines: bootstrap = bootstrap.replace(line, '')
    project.write_text(bootstrap, encoding='utf-8')
    result = subprocess.run(args)
    if result.returncode: raise SystemExit(result.returncode)
finally:
    project.write_text(original, encoding='utf-8')
raise SystemExit(subprocess.run(args).returncode)
