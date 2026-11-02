"""Reproducible, lossless export preparation and content-addressed Pages packaging."""
from pathlib import Path
import argparse
import collections
import gzip
import hashlib
import json
import os
import re
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
WEB = BUILD / 'web'

def source_files():
    return [p for p in ROOT.rglob('*') if p.is_file() and not any(
        x in {'.git', '.godot', 'build', 'output', 'artifacts', '__pycache__'} for x in p.relative_to(ROOT).parts)]

def prepare():
    files = source_files()
    # Exact literals stay exact; retain WHOLE directories for JSON siblings,
    # concatenated paths and sprintf paths. Never infer individual frame usage.
    directories = set()
    literals = set()
    for p in files:
        if p.suffix not in {'.gd', '.tscn', '.gdshader', '.gdshaderinc', '.godot'}: continue
        for ref in re.findall(r'"res://([^"\r\n]+)"', p.read_text(encoding='utf-8-sig')):
            literals.add(ref)
            if ref.endswith('/') or '%' in ref or ref.endswith('.json'):
                directory = ref if ref.endswith('/') else ref.rsplit('/', 1)[0] + '/'
                directories.add(directory)
    excluded = []
    for p in files:
        name = p.relative_to(ROOT).as_posix()
        if name.startswith(('art/', 'stages/')) and p.suffix in {'.png', '.jpg', '.jpeg', '.svg', '.webp', '.ttf'}:
            if name not in literals and not any(name.startswith(d) for d in directories): excluded.append(name)
    preset = ROOT / 'export_presets.cfg'
    text = preset.read_text(encoding='utf-8-sig')
    index = text.index('[preset.2]')
    text = text[:index] + re.sub(r'^exclude_filter="[^"]*"',
        'exclude_filter="' + ','.join(['output/*', 'artifacts/*', 'tests/*', 'tools/*', 'build/*', 'web/*', 'docs/*', '하이라이트/*'] + sorted(excluded)) + '"',
        text[index:], count=1, flags=re.M)
    preset.write_text(text, encoding='utf-8')
    BUILD.mkdir(exist_ok=True)
    duplicates = collections.defaultdict(list)
    for p in files:
        if p.suffix in {'.png', '.mp3'}:
            duplicates[hashlib.sha256(p.read_bytes()).hexdigest()].append(p.relative_to(ROOT).as_posix())
    top = sorted(files, key=lambda p: p.stat().st_size, reverse=True)[:30]
    oversized = []
    for p in files:
        if p.suffix.lower() != '.png': continue
        with p.open('rb') as stream: header = stream.read(24)
        if header[:8] == b'\x89PNG\r\n\x1a\n':
            width, height = struct.unpack('>II', header[16:24])
            if max(width, height) > 4096:
                oversized.append({'path': p.relative_to(ROOT).as_posix(), 'width': width, 'height': height})
    report = {
        'source_bytes': sum(p.stat().st_size for p in files),
        'textures_over_4096': oversized,
        'largest_30': [{'path': p.relative_to(ROOT).as_posix(), 'bytes': p.stat().st_size} for p in top],
        'over_100_mib': [p.relative_to(ROOT).as_posix() for p in files if p.stat().st_size >= 100 * 1024**2],
        'excluded_from_web_only': sorted(excluded),
        'excluded_source_bytes': sum((ROOT / p).stat().st_size for p in excluded),
        'retained_dynamic_directories': sorted(directories),
        'exact_duplicate_groups': [paths for paths in duplicates.values() if len(paths) > 1],
        'source_audio_bytes': sum(p.stat().st_size for p in files if p.suffix == '.mp3'),
        'source_image_bytes': sum(p.stat().st_size for p in files if p.suffix in {'.png', '.jpg', '.jpeg', '.webp', '.svg'}),
    }
    (BUILD / 'resource-audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    # Replace only generated output, never source assets.
    if WEB.exists():
        if WEB.resolve().parent != (ROOT / 'build').resolve(): raise SystemExit('Unsafe output path')
        shutil.rmtree(WEB)
    WEB.mkdir(parents=True, exist_ok=True)
    print(f'Excluded {len(excluded)} unreferenced-directory assets from web only; originals preserved.')
    if report['over_100_mib']: raise SystemExit('Source exceeds GitHub single-file limit')

def finish():
    html = (WEB / 'index.html').read_text(encoding='utf-8')
    measurement = os.environ.get('GA4_MEASUREMENT_ID', '').strip()
    if measurement and not re.fullmatch(r'G-[A-Z0-9]+', measurement):
        raise SystemExit('Invalid GA4_MEASUREMENT_ID; refusing script injection')
    if html.count('__GA4_ID__') != 1: raise SystemExit('Missing or repeated GA4 configuration marker')
    html = html.replace('__GA4_ID__', measurement)
    shutil.copyfile(ROOT / 'web/analytics.js', WEB / 'analytics.js')
    required = ['index.js', 'index.wasm', 'index.pck', 'index.audio.worklet.js', 'index.audio.position.worklet.js']
    for name in required:
        if not (WEB / name).is_file() or not (WEB / name).stat().st_size: raise SystemExit(f'Missing {name}')
    if 'GODOT_THREADS_ENABLED = false' not in html: raise SystemExit('Threaded build is not supported on Pages')
    assets = [p for p in WEB.iterdir() if p.is_file() and p.name != 'index.html']
    release = hashlib.sha256(b''.join(hashlib.sha256(p.read_bytes()).digest() for p in sorted(assets))).hexdigest()[:16]
    destination = WEB / 'releases' / release
    destination.mkdir(parents=True, exist_ok=True)
    manifest = []
    for p in assets:
        data = p.read_bytes()
        manifest.append({'name': p.name, 'bytes': len(data), 'gzip_estimate_bytes': len(gzip.compress(data, compresslevel=6)),
                         'sha256': hashlib.sha256(data).hexdigest()})
        html = html.replace('"' + p.name + '"', '"releases/' + release + '/' + p.name + '"')
        shutil.move(str(p), str(destination / p.name))
    html = html.replace('"executable":"index"', '"executable":"releases/' + release + '/index"')
    # Every generated binary, worklet and image shares one immutable version prefix.
    (WEB / 'index.html').write_text(html, encoding='utf-8')
    (WEB / '.nojekyll').touch()
    total = sum(p.stat().st_size for p in WEB.rglob('*') if p.is_file())
    if total >= 1_000_000_000: raise SystemExit('Published site exceeds conservative 1 GB Pages limit')
    if re.search(r'(?:src|href)="/(?!/)', html): raise SystemExit('Root-absolute asset URL breaks project Pages')
    if '$GODOT_' in html: raise SystemExit('Unexpanded Godot template marker')
    report = {'release': release, 'site_bytes': total, 'assets': manifest,
              'estimated_gzip_bytes': sum(r['gzip_estimate_bytes'] for r in manifest),
              'actual_browser_transfer_bytes': None, 'runtime_verified': False}
    (BUILD / 'web-size-report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['prepare', 'finish'])
    args = parser.parse_args()
    prepare() if args.command == 'prepare' else finish()
