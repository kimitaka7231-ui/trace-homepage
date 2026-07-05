# パーソナルジム TRACE — ローカルプレビューサーバー
# 起動: powershell -ExecutionPolicy Bypass -File .\start-server.ps1
# URL : http://localhost:8765/

$ErrorActionPreference = 'Stop'
$port = 8765
$root = $PSScriptRoot

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$port/")
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()

Write-Host "Serving at http://localhost:$port/"
Write-Host "Root: $root"
Write-Host "Press Ctrl+C to stop."

while ($listener.IsListening) {
  $context = $listener.GetContext()
  $path = $context.Request.Url.LocalPath
  if ($path -eq '/') { $path = '/index.html' }

  $file = Join-Path $root ($path.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar))

  if (Test-Path $file -PathType Leaf) {
    $bytes = [IO.File]::ReadAllBytes($file)
    $ext = [IO.Path]::GetExtension($file).ToLower()
    $ctype = switch ($ext) {
      '.html' { 'text/html; charset=utf-8' }
      '.css'  { 'text/css; charset=utf-8' }
      '.js'   { 'application/javascript; charset=utf-8' }
      '.svg'  { 'image/svg+xml' }
      '.png'  { 'image/png' }
      '.jpg'  { 'image/jpeg' }
      '.jpeg' { 'image/jpeg' }
      '.webp' { 'image/webp' }
      '.ico'  { 'image/x-icon' }
      default { 'application/octet-stream' }
    }
    $context.Response.ContentType = $ctype
    $context.Response.ContentLength64 = $bytes.Length
    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  } else {
    $context.Response.StatusCode = 404
    $msg = [Text.Encoding]::UTF8.GetBytes('404 Not Found')
    $context.Response.OutputStream.Write($msg, 0, $msg.Length)
  }

  $context.Response.Close()
}
