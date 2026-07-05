# TRACE 宣材写真 — 一括レタッチ
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$srcDir = "C:\Users\kimit\.cursor\projects\c-Users-kimit-OneDrive-TRACE\assets"
$outDir = Join-Path $root "assets\img"
$exe = Join-Path $PSScriptRoot "TracePhotoRetouch.exe"
$cs = Join-Path $PSScriptRoot "TracePhotoRetouch.cs"
$csc = "${env:WINDIR}\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

Write-Host "Compiling retouch tool..."
& $csc /nologo /optimize+ /unsafe /out:$exe $cs
if ($LASTEXITCODE -ne 0) { throw "Compile failed" }

$jobs = @(
    @{
        In  = "c__Users_kimit_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_HP-8dcba793-78a7-497a-8e0e-cd2f0f1288ca.png"
        Out = "training-stretch.png"
    },
    @{
        In  = "c__Users_kimit_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_HP_-2e015993-13e2-4c75-841a-03c2f720a32f.png"
        Out = "training-dumbbell.png"
    },
    @{
        In  = "c__Users_kimit_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images______-c82832dc-d801-4777-82c8-0e5dfd49a8be.png"
        Out = "training-squat.png"
    },
    @{
        In  = "c__Users_kimit_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images____-7fbc11d5-5f4c-4302-8433-92ad00d1dbc9.png"
        Out = "training-bench.png"
    },
    @{
        In  = "c__Users_kimit_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images______-68a6b3f2-80c5-43ad-ab84-0e104fcbc78a.png"
        Out = "training-lat-pulldown.png"
    }
)

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

foreach ($job in $jobs) {
    $input = Join-Path $srcDir $job.In
    $output = Join-Path $outDir $job.Out
    if (-not (Test-Path $input)) {
        Write-Warning "Missing: $($job.In)"
        continue
    }
    Write-Host "Retouching -> $($job.Out)"
    & $exe $input $output
}

Write-Host "Done. Output: $outDir"
