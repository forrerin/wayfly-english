# Локальный сервер для собранного сайта: ничего устанавливать не нужно, работает на любом Windows 10/11
$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..\wayfly-english' | Resolve-Path
$base = '/wayfly-english/'

$types = @{
  '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
  '.svg' = 'image/svg+xml'; '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.woff2' = 'font/woff2'
  '.json' = 'application/json'; '.webmanifest' = 'application/manifest+json'; '.xml' = 'application/xml'; '.txt' = 'text/plain; charset=utf-8'
}

# первый свободный порт начиная с 8080
$listener = $null
foreach ($port in 8080..8099) {
  try {
    $l = New-Object System.Net.HttpListener
    $l.Prefixes.Add("http://localhost:$port/")
    $l.Start()
    $listener = $l
    break
  } catch { }
}
if (-not $listener) { Write-Host 'Не нашёлся свободный порт 8080–8099. Закройте лишние программы и запустите снова.'; exit 1 }

$url = "http://localhost:$port$base"
Write-Host ''
Write-Host '  Wayfly English запущен' -ForegroundColor Green
Write-Host "  $url"
Write-Host ''
Write-Host '  Сайт открылся в браузере. Пока это окно открыто — сайт работает.'
Write-Host '  Чтобы выключить, просто закройте окно.'
Write-Host ''
Start-Process $url

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request
  $res = $ctx.Response
  try {
    $path = [Uri]::UnescapeDataString($req.Url.AbsolutePath)
    if (-not $path.StartsWith($base)) {
      $res.StatusCode = 302
      $res.RedirectLocation = $base
    } elseif ($req.HttpMethod -ne 'GET' -and $req.HttpMethod -ne 'HEAD') {
      # форма в демо-версии ничего не отправляет
      $res.StatusCode = 405
    } else {
      $rel = $path.Substring($base.Length)
      if ($rel -eq '' -or $rel.EndsWith('/')) { $rel += 'index.html' }
      $file = [IO.Path]::GetFullPath((Join-Path $root $rel))
      if ($file.StartsWith($root.Path) -and (Test-Path $file -PathType Leaf)) {
        $bytes = [IO.File]::ReadAllBytes($file)
        $ext = [IO.Path]::GetExtension($file).ToLower()
        $res.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { 'application/octet-stream' }
        $res.ContentLength64 = $bytes.Length
        if ($req.HttpMethod -eq 'GET') { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
      } else {
        $res.StatusCode = 404
      }
    }
  } catch {
    $res.StatusCode = 500
  } finally {
    $res.Close()
  }
}
