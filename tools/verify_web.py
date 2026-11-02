"""HTTP asset contract check. Does not start Godot, WebAssembly or a browser."""
import http.server
import json
from pathlib import Path
import re
import threading
import urllib.request

root = Path(__file__).resolve().parents[1]
site = root / 'build/web'
html = (site / 'index.html').read_text(encoding='utf-8')
config = json.loads(re.search(r'const GODOT_CONFIG = (.*);', html)[1])
assert config['executable'].startswith('releases/')
assert config['ensureCrossOriginIsolationHeaders'] is False
urls = re.findall(r'(?:src|href)="([^"]+)"', html)
urls += list(config['fileSizes'])
urls += [config['executable'] + suffix for suffix in ['.audio.worklet.js', '.audio.position.worklet.js']]
assert not any(url.startswith(('/', 'http:', 'https:')) for url in urls)
for name, size in config['fileSizes'].items():
    assert (site / name).stat().st_size == size

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs): super().__init__(*args, directory=str(site), **kwargs)
    def translate_path(self, path):
        assert path.startswith('/FlowerOfYeon/')
        return super().translate_path(path[len('/FlowerOfYeon'):])
    def log_message(self, *_args): pass

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    for url in ['', *urls]:
        request = urllib.request.Request(f'http://127.0.0.1:{server.server_port}/FlowerOfYeon/' + url, method='HEAD')
        with urllib.request.urlopen(request) as response:
            assert response.status == 200
            if url.endswith('.wasm'): assert response.headers['Content-Type'] == 'application/wasm'
    print(f'HTTP HEAD passed for {len(urls)+1} URLs under /FlowerOfYeon/; no game executed.')
finally:
    server.shutdown()
    server.server_close()
