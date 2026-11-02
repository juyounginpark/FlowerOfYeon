import importlib.util
from pathlib import Path
import unittest

class ExportContract(unittest.TestCase):
    def test_all_literal_paths_keep_original_case(self):
        import re
        root = Path(__file__).resolve().parents[1]
        missing = []
        for folder in ['scripts', 'scenes', 'shaders']:
            for source in (root / folder).rglob('*'):
                if source.suffix not in {'.gd', '.tscn', '.gdshader', '.gdshaderinc'}: continue
                for name in re.findall(r'"res://([^"\r\n]+)"', source.read_text(encoding='utf-8-sig')):
                    if '%' in name or name.endswith('/'): continue
                    target = root / name
                    if not target.exists(): missing.append((str(source.relative_to(root)), name))
                    elif target.name not in [p.name for p in target.parent.iterdir()]: missing.append((str(source), name))
        self.assertEqual(missing, [])

    def test_no_csharp_or_extension_dependency(self):
        root = Path(__file__).resolve().parents[1]
        self.assertEqual(list((root / 'scripts').rglob('*.cs')), [])
        self.assertEqual(list((root / 'scripts').rglob('*.gdextension')), [])
