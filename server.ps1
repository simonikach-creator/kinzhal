$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = 8080
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
try {
  $listener.Start()
} catch {
  Write-Host "Не удалось запустить Кинжал на порту $port." -ForegroundColor Red
  Write-Host $_.Exception.Message
  Read-Host "Нажми Enter для выхода"
  exit 1
}
Write-Host "Кинжал запущен: http://localhost:$port" -ForegroundColor Green
Write-Host "Не закрывай это окно, пока пользуешься приложением на ноутбуке." -ForegroundColor Yellow
Start-Process "http://localhost:$port"
$mime = @{
  '.html'='text/html; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.js'='application/javascript; charset=utf-8';
  '.json'='application/json; charset=utf-8'; '.webmanifest'='application/manifest+json; charset=utf-8'; '.png'='image/png'; '.svg'='image/svg+xml'; '.ico'='image/x-icon'
}
try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 4096, $true)
      $requestLine = $reader.ReadLine()
      if (-not $requestLine) { $client.Close(); continue }
      while (($line = $reader.ReadLine()) -ne '') { if ($null -eq $line) { break } }
      $parts = $requestLine.Split(' ')
      $method = $parts[0]
      $urlPath = if ($parts.Count -gt 1) { $parts[1].Split('?')[0] } else { '/' }
      $urlPath = [System.Uri]::UnescapeDataString($urlPath)
      if ($urlPath -eq '/') { $urlPath = '/index.html' }
      $relative = $urlPath.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar)
      $candidate = [IO.Path]::GetFullPath((Join-Path $root $relative))
      $rootFull = [IO.Path]::GetFullPath($root + [IO.Path]::DirectorySeparatorChar)
      if (-not $candidate.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        $body = [Text.Encoding]::UTF8.GetBytes('404 Not Found')
        $header = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
      } else {
        $body = [IO.File]::ReadAllBytes($candidate)
        $ext = [IO.Path]::GetExtension($candidate).ToLowerInvariant()
        $type = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
        $header = "HTTP/1.1 200 OK`r`nContent-Type: $type`r`nContent-Length: $($body.Length)`r`nCache-Control: no-cache`r`nConnection: close`r`n`r`n"
      }
      $headerBytes = [Text.Encoding]::ASCII.GetBytes($header)
      $stream.Write($headerBytes,0,$headerBytes.Length)
      if ($method -ne 'HEAD') { $stream.Write($body,0,$body.Length) }
      $stream.Flush()
    } catch {} finally { $client.Close() }
  }
} finally { $listener.Stop() }
