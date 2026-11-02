param([string]$Godot = 'godot')
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $projectPath
try {
    python tools/web_pipeline.py prepare
    if ($LASTEXITCODE -ne 0) { throw 'Web preparation failed' }
    python tools/import_project.py $Godot
    if ($LASTEXITCODE -ne 0) { throw 'Resource import failed' }
    & $Godot --headless --rendering-driver dummy --audio-driver Dummy --export-release Web build/web/index.html
    if ($LASTEXITCODE -ne 0) { throw 'Web release export failed' }
    python tools/web_pipeline.py finish
    if ($LASTEXITCODE -ne 0) { throw 'Web packaging failed' }
    python tools/verify_web.py
    if ($LASTEXITCODE -ne 0) { throw 'HTTP asset verification failed' }
} finally { Pop-Location }
