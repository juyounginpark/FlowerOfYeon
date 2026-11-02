# Offline source-image analysis only. Writes UV coordinates, never edits the art.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
public static class ChartDotMapper {
    public static List<double[]> Read(string path) {
        var points = new List<double[]>();
        using (var image = new Bitmap(path)) {
            const int size = 820;
            var mask = new bool[size*size];
            var seen = new bool[mask.Length];
            for (int y=0;y<size;y++) for(int x=0;x<size;x++) {
                var c=image.GetPixel(x+12,y+158);
                double dx=x-400,dy=y-410;
                bool dark=c.R<92 && c.G<85 && c.B<75;
                bool red=c.R>c.G*1.35 && c.G<112 && c.R<195;
                mask[y*size+x]=c.A>128 && dx*dx+dy*dy<378*378 && (dark || red);
            }
            for(int start=0;start<mask.Length;start++) {
                if(!mask[start] || seen[start]) continue;
                var queue=new Queue<int>();queue.Enqueue(start);seen[start]=true;
                int count=0,minX=size,minY=size,maxX=0,maxY=0;double sx=0,sy=0;
                while(queue.Count>0) {
                    int p=queue.Dequeue(),x=p%size,y=p/size;
                    count++;sx+=x;sy+=y;minX=Math.Min(minX,x);maxX=Math.Max(maxX,x);minY=Math.Min(minY,y);maxY=Math.Max(maxY,y);
                    for(int oy=-1;oy<=1;oy++) for(int ox=-1;ox<=1;ox++) {
                        int nx=x+ox,ny=y+oy;
                        if(nx<0 || ny<0 || nx>=size || ny>=size)continue;
                        int n=ny*size+nx;
                        if(mask[n] && !seen[n]) {seen[n]=true;queue.Enqueue(n);}
                    }
                }
                int w=maxX-minX+1,h=maxY-minY+1;
                // Reject constellation lines, lettering and scan noise; retain
                // compact ink dots (including red stars) at their real centers.
                if(count>=6 && count<=85 && w>=3 && h>=3 && w<=12 && h<=12 &&
                   Math.Max(w,h)<=Math.Min(w,h)*2.5 && count/(double)(w*h)>=.32) {
                    points.Add(new double[]{Math.Round((sx/count+.5)/size,6),Math.Round((sy/count+.5)/size,6),Math.Round(Math.Sqrt(count/Math.PI),3)});
                }
            }
        }
        return points;
    }
}
'@
$taskRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $taskRoot 'stages/8-견우와직녀/remove_background-5.png'
$points = [ChartDotMapper]::Read($source)
$mapping = [ordered]@{source='res://stages/8-견우와직녀/remove_background-5.png';crop=@(12,158,820,820);method='Compact dark/red ink components inside chart disc; UV centers and source radius in pixels';count=$points.Count;points=@($points.ToArray())}
$mapping | ConvertTo-Json -Depth 6 -Compress | Set-Content -Encoding utf8 (Join-Path $taskRoot 'art/minhwa/gyeonwu_rework/chart_stars.json')
Write-Output "Mapped $($points.Count) chart dots."
