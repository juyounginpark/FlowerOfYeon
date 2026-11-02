# CPU-only image inspection. Does not start Godot or alter generated PNGs.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System.Drawing;
public static class Stage6AlphaAudit {
    public static int[] Bounds(string path, int x0, int y0, int w, int h) {
        using (var image = new Bitmap(path)) {
            if (w == 0) { w = image.Width; h = image.Height; }
            int left=w, top=h, right=-1, bottom=-1, edge=0;
            for (int y=0;y<h;y++) for (int x=0;x<w;x++) {
                if (image.GetPixel(x+x0,y+y0).A < 32) continue;
                left=System.Math.Min(left,x); right=System.Math.Max(right,x);
                top=System.Math.Min(top,y); bottom=System.Math.Max(bottom,y);
                if(x==0 || y==0 || x==w-1 || y==h-1) edge++;
            }
            return new int[]{left,top,right-left+1,bottom-top+1,edge};
        }
    }
}
'@
$artDirectory = Join-Path $PSScriptRoot '../art/minhwa/stage6_rework'
$report = [ordered]@{ alpha_threshold=32; frames=@(); eat_frames=@(); images=[ordered]@{} }
$sheetPath = Join-Path $artDirectory 'tiger_run.png'
$sheet = [Drawing.Bitmap]::new($sheetPath)
$cellWidth = [int]($sheet.Width/3)
$cellHeight = [int]($sheet.Height/2)
$sheet.Dispose()
for ($index=0; $index -lt 6; $index++) {
    $x=($index%3)*$cellWidth
    $y=[math]::Floor($index/3)*$cellHeight
    $bounds=[Stage6AlphaAudit]::Bounds($sheetPath,$x,$y,$cellWidth,$cellHeight)
    if ($index -lt 5) {
        if ($bounds[2] -le 0 -or $bounds[3] -le 0 -or $bounds[4] -ne 0) { throw "Frame $index is empty or crosses its cell boundary" }
        $report.frames += [ordered]@{cell=@($x,$y,$cellWidth,$cellHeight); ink=@($bounds[0],$bounds[1],$bounds[2],$bounds[3]); edge_pixels=$bounds[4]}
    } elseif ($bounds[2] -gt 0) { throw 'The unused sixth cell contains visible ink' }
}
$eatPath = Join-Path $artDirectory 'tiger_eat.png'
$eatSheet = [Drawing.Bitmap]::new($eatPath)
$eatWidth=$eatSheet.Width; $eatHeight=$eatSheet.Height
$eatSheet.Dispose()
for ($index=0; $index -lt 3; $index++) {
    $x=[int][math]::Floor($index*$eatWidth/3)
    $end=[int][math]::Floor(($index+1)*$eatWidth/3)
    $bounds=[Stage6AlphaAudit]::Bounds($eatPath,$x,0,$end-$x,$eatHeight)
    if ($bounds[2] -le 0 -or $bounds[4] -ne 0) { throw "Eating frame $index is empty or crosses its cell" }
    $report.eat_frames += [ordered]@{cell=@($x,0,($end-$x),$eatHeight); ink=@($bounds[0],$bounds[1],$bounds[2],$bounds[3]); edge_pixels=$bounds[4]}
}
foreach ($id in @('rice','rice_basket','siblings_climb','rope','tiger_sleep','tiger_climb','tiger_fall','knockback_impact','mother')) {
    $bounds=[Stage6AlphaAudit]::Bounds((Join-Path $artDirectory "$id.png"),0,0,0,0)
    if ($bounds[2] -le 0) { throw "Empty asset: $id" }
    $report.images[$id]=@($bounds[0],$bounds[1],$bounds[2],$bounds[3])
}
$json=$report | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText((Join-Path $artDirectory 'frame-regions.json'),$json,(New-Object Text.UTF8Encoding($false)))
Write-Output $json
