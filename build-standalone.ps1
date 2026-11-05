# ======================================================================
# build-standalone.ps1 — 把整個工具包進單一 img2pixel.bat（自包含單檔）
#
# 為什麼要這樣：直接雙擊 .html（file://）時，瀏覽器下載的檔案會被
# Windows 標記為 ZoneId=4（限制的網站）而封鎖開啟／解壓；網頁沙箱又
# 無法自己啟動本機伺服器，所以一定要一個「瀏覽器之外的啟動器」。
# 這個 .bat 把整個 img2pixel.html 內嵌在檔案後段，雙擊時：
#   1. 前段 cmd 呼叫 PowerShell 讀取本檔、抽出後段程式並執行
#   2. PowerShell 用內建 HttpListener 在記憶體裡直接服務頁面
#      （不需要 Python ；只監聽 localhost）
#   3. 自動開啟瀏覽器 → 下載標記為一般區域（ZoneId=3）→ 存檔正常
#
# 維護流程：改完 img2pixel.html 後執行本腳本重新產生 img2pixel.bat。
# 注意：前段（cmd 可達的部分）必須保持純 ASCII；HTML 區塊位於
#       「exit /b」之後，永遠不會被 cmd 剖析，可含任意字元。
# ======================================================================
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$src=Join-Path $root 'img2pixel.html'
$out=Join-Path $root 'img2pixel.bat'
$nl=[char]13+[char]10   # CRLF：cmd 批次檔必需

if(-not (Test-Path $src)){ throw "找不到 $src" }
# 原始 html 必須是 UTF-8 無 BOM、CRLF 行尾（工具本體就是）
$html=[IO.File]::ReadAllText($src,[Text.UTF8Encoding]::new($false))

# ---------- 前段：cmd 啟動器（純 ASCII） ----------
# 標記字串用字串連接組出來，避免「第一次出現」被前段自己吃掉
$preLines=@(
  '@echo off',
  'title img2pixel - local server',
  'rem ====================================================================',
  'rem  IMG2PIXEL single-file launcher (Windows)',
  'rem  Double-click this ONE file: it starts a tiny local server',
  'rem  in memory (no Python needed) and opens your browser.',
  'rem  Downloads then get a normal zone mark, so Windows will NOT',
  'rem  block the exported ZIP / PNG when opening or unzipping.',
  'rem',
  'rem  Keep this window open while using the tool.',
  'rem  Close this window (or Ctrl+C) to stop the server.',
  'rem ====================================================================',
  'powershell -NoProfile -ExecutionPolicy Bypass -Command "$I2P_TXT=[IO.File]::ReadAllText(''%~f0'', [Text.UTF8Encoding]::new($false)); $i=$I2P_TXT.IndexOf(((''#I2P_PS_'')+(''START#''))); $j=$I2P_TXT.IndexOf(((''#I2P_PS_'')+(''END#''))); iex ($I2P_TXT.Substring($i+14, $j-$i-14))"',
  'exit /b'
)
$pre=($preLines -join $nl)+$nl

# ---------- 中段：PowerShell 伺服器（永遠不會被 cmd 執行） ----------
$psLines=@(
  '$ErrorActionPreference=''Stop''',
  '# ---- 1. pick a free port (starts at 8799) ----',
  '$port=8799',
  'while($port -lt 8930){',
  '  try{ $probe=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$port); $probe.Start(); $probe.Stop(); break }',
  '  catch{ $port++ }',
  '}',
  '# ---- 2. extract the embedded tool page (kept in memory only) ----',
  '$m1=(''#I2P_HTML_'')+(''START#''); $m2=(''#I2P_HTML_'')+(''END#'')',
  '$a=$I2P_TXT.IndexOf($m1); $b=$I2P_TXT.IndexOf($m2)',
  'if(($a -lt 0) -or ($b -lt $a)){ Write-Host ''ERROR: embedded page not found (is this file damaged?)''; exit 1 }',
  '$html=[Text.Encoding]::UTF8.GetBytes($I2P_TXT.Substring($a+$m1.Length, $b-$a-$m1.Length))',
  '# ---- 3. serve it on http://localhost:<port> ----',
  '$h=[Net.HttpListener]::new()',
  '$h.Prefixes.Add(''http://localhost:''+$port+''/'')',
  'try{ $h.Start() }catch{ Write-Host (''ERROR: cannot listen on port ''+$port+'' : ''+$_.Exception.Message); exit 1 }',
  '[IO.File]::WriteAllText((Join-Path $env:TEMP ''i2p_server.pid''), $PID)',
  '$url=(''http://localhost:''+$port+''/'')',
  'Write-Host ''''',
  'Write-Host ''  ==============================================================''',
  'Write-Host (''   IMG2PIXEL is running :  ''+$url)',
  'Write-Host ''   Tool opened in your browser. Keep this window open while using.''',
  'Write-Host ''   Close this window (or press Ctrl+C) to stop.''',
  'Write-Host ''  ==============================================================''',
  'Write-Host ''''',
  'if($env:I2P_NO_BROWSER -ne ''1''){ Start-Process $url }',
  'while($h.IsListening){',
  '  try{',
  '    $ctx=$h.GetContext(); $res=$ctx.Response',
  '    if($ctx.Request.Url.AbsolutePath -eq ''/favicon.ico''){ $res.StatusCode=404 }',
  '    else{',
  '      $res.ContentType=''text/html; charset=utf-8''',
  '      $res.Headers.Add(''Cache-Control'',''no-store'')',
  '      $res.ContentLength64=$html.Length',
  '      $res.OutputStream.Write($html,0,$html.Length)',
  '    }',
  '    $res.OutputStream.Close()',
  '  }catch{ Start-Sleep -Milliseconds 50 }',
  '}',
  ''
)
$ps=($psLines -join $nl)

# ---------- 組檔 ----------
$content = $pre
$content += '#I2P_PS_START#'+$nl + $ps + $nl
$content += '#I2P_PS_END#'+$nl
$content += '#I2P_HTML_START#'+$nl + $html + $nl
$content += '#I2P_HTML_END#'+$nl
[IO.File]::WriteAllText($out,$content,[Text.UTF8Encoding]::new($false))

$size=(Get-Item $out).Length
Write-Host "OK: $out ($size bytes)"
