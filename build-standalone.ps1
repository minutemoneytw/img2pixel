# ======================================================================
# build-standalone.ps1 - pack the whole tool into a single img2pixel.bat
# ASCII only: Windows PowerShell 5.1 misreads no-BOM UTF-8 scripts as ANSI.
# ======================================================================
# How it works (why a .bat and not a plain .html):
#   Double-clicking the .html (file://) marks every browser download as
#   ZoneId=4 (restricted) and Windows blocks opening/unzipping it. A web
#   page cannot start a local server by itself, so a launcher outside the
#   browser is always required. This .bat embeds img2pixel.html in its
#   tail (after "exit /b", so cmd never parses it) and on run:
#     1. head (cmd) feeds the file to PowerShell which extracts and runs
#        the embedded PowerShell section,
#     2. PowerShell serves the page from memory with the built-in
#        HttpListener (localhost only, no Python needed),
#     3. opens the browser: downloads are then marked Zone 3 (normal),
#        so saving / unzipping / opening exports all work.
#
# Maintainer workflow: edit img2pixel.html, run this script to refresh
# img2pixel.bat. (Keep the cmd-reachable head pure ASCII. The HTML block
# sits after "exit /b" and can contain anything.)
# ======================================================================
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$src=Join-Path $root 'img2pixel.html'
$ico=Join-Path $root 'img2pixel.ico'
$out=Join-Path $root 'img2pixel.bat'
$nl=[char]13+[char]10   # CRLF: required by cmd batch files

if(-not (Test-Path $src)){ throw "source not found: $src" }
if(-not (Test-Path $ico)){ throw "icon not found: $ico (generate with draw-ico.js first)" }
# Tool page must be UTF-8 without BOM, CRLF endings (it already is).
$html=[IO.File]::ReadAllText($src,[Text.UTF8Encoding]::new($false))

# ---------- head: cmd side (pure ASCII) ----------
# Marker strings are built by concatenation so the FIRST occurrence of
# each marker in the file is the real section, not the bootstrap code.
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
  'rem  Runs hidden: no window stays open (it closes by itself).',
  'rem  The background server auto-stops ~15 min after the tool',
  'rem  page is closed, or immediately via the tool''s stop button.',
  'rem  First run also creates a desktop shortcut with a pixel icon.',
  'rem ====================================================================',
  'powershell -NoProfile -ExecutionPolicy Bypass -Command "$I2P_SELF=(''%~f0''); $I2P_TXT=[IO.File]::ReadAllText($I2P_SELF, [Text.UTF8Encoding]::new($false)); $i=$I2P_TXT.IndexOf(((''#I2P_PS_'')+(''START#''))); $j=$I2P_TXT.IndexOf(((''#I2P_PS_'')+(''END#''))); $s=$I2P_TXT.Substring($i+14, $j-$i-14); $b=Join-Path $env:TEMP ''i2p_boot.ps1''; [IO.File]::WriteAllText($b, $s, [Text.UTF8Encoding]::new($false)); Start-Process powershell -WindowStyle Hidden -ArgumentList @(''-NoProfile'',''-ExecutionPolicy'',''Bypass'',''-File'',$b,$I2P_SELF)"',
  'exit /b'
)
$pre=($preLines -join $nl)+$nl

# ---------- middle: PowerShell server (never parsed by cmd) ----------
$psLines=@(
  'param([string]$batPath='''')',
  '$ErrorActionPreference=''Stop''',
  'try{',
  '  if(!$batPath){ throw ''bootstrap did not pass the bat path'' }',
  '  $I2P_TXT=[IO.File]::ReadAllText($batPath, [Text.UTF8Encoding]::new($false))',
  '@ICO@',
  '$srvLog=Join-Path (Join-Path $env:LOCALAPPDATA "img2pixel") "server.log"',
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
  'try{ $h.Start() }catch{ try{ Set-Content $srvLog ("listen FAIL port="+$port+" : "+$_.Exception.InnerException.Message+" / "+$_.Exception.Message) }catch{ }; exit 1 }',
  '[IO.File]::WriteAllText((Join-Path $env:TEMP ''i2p_server.pid''), $PID)',
  '$url=(''http://localhost:''+$port+''/'')',
  '# ---- 4. desktop shortcut with the pixel icon (created on first run) ----',
  'try{',
  '  $icoDir=Join-Path $env:LOCALAPPDATA ''img2pixel''',
  '  if(!(Test-Path $icoDir)){ New-Item -ItemType Directory -Path $icoDir -Force | Out-Null }',
  '  $icoPath=Join-Path $icoDir ''img2pixel.ico''',
  '  try{ [IO.File]::WriteAllBytes($icoPath, [Convert]::FromBase64String($I2P_ICO_B64)) }catch{ }',
  '  $lnkPath=Join-Path ([Environment]::GetFolderPath(''Desktop'')) ''img2pixel.lnk''',
  '  $need=$true',
  '  if(Test-Path $lnkPath){',
  '    $old=(New-Object -ComObject WScript.Shell).CreateShortcut($lnkPath)',
  '    if(($old.TargetPath -eq $I2P_SELF) -and ($old.IconLocation -like ($icoPath+''*''))){ $need=$false }',
  '  }',
  '  if($need){',
  '    $sc=(New-Object -ComObject WScript.Shell).CreateShortcut($lnkPath)',
  '    $sc.TargetPath=$I2P_SELF',
  '    $sc.WorkingDirectory=(Split-Path -Parent $I2P_SELF)',
  '    $sc.IconLocation=($icoPath+'',0'')',
  '    $sc.Save()',
  '    Write-Host (''   Desktop shortcut ready: ''+$lnkPath)',
  '  }',
  '}catch{ }',
  'Write-Host ''''',
  'Write-Host ''  ==============================================================''',
  'Write-Host (''   IMG2PIXEL is running :  ''+$url)',
  'Write-Host ''   Hidden mode: this console is not visible. Server log:''',
  'Write-Host ''     %LOCALAPPDATA%\img2pixel\server.log''',
  'Write-Host ''   Auto-stop after 15 min without tool heartbeat, or via /stop.''',
  'Write-Host ''  ==============================================================''',
  'Write-Host ''''',
  'if($env:I2P_NO_BROWSER -ne ''1''){ Start-Process $url }',
  '# ---- 5. serve loop: /ping = heartbeat keep-alive; idle 15 min = stop; /stop = quit ----',
  '$srvLog=Join-Path (Join-Path $env:LOCALAPPDATA "img2pixel") "server.log"',
  'try{ Set-Content $srvLog ("start "+(Get-Date -Format s)+" port="+$port+" pid="+$PID) }catch{ }',
  '$lastBeat=[DateTime]::Now',
  '$idleMin=15',
  'if($env:I2P_IDLE_MIN){ $idleMin=[double]$env:I2P_IDLE_MIN }',
  '$byBreak=""',
  'while($h.IsListening){',
  '  $task=$h.GetContextAsync()',
  '  $idleKill=$false',
  '  while(-not $task.Wait(2000)){',
  '    if((New-TimeSpan $lastBeat (Get-Date)).TotalMinutes -gt $idleMin){ $idleKill=$true; break }',
  '  }',
  '  if($idleKill){ $byBreak="idle"; break }',
  '  try{',
  '    $ctx=$task.Result; $res=$ctx.Response',
  '    $p=$ctx.Request.Url.AbsolutePath',
  '    $lastBeat=[DateTime]::Now',
  '    if($p -eq "/favicon.ico"){ $res.StatusCode=404 }',
  '    elseif($p -eq "/ping"){',
  '      $res.ContentType="text/plain; charset=utf-8"',
  '      $outb=[Text.Encoding]::UTF8.GetBytes("img2pixel-local-server")',
  '      $res.ContentLength64=$outb.Length; $res.OutputStream.Write($outb,0,$outb.Length)',
  '    }',
  '    elseif($p -eq "/stop"){',
  '      $res.ContentType="text/plain; charset=utf-8"',
  '      $outb=[Text.Encoding]::UTF8.GetBytes("bye")',
  '      $res.ContentLength64=$outb.Length; $res.OutputStream.Write($outb,0,$outb.Length)',
  '      $res.OutputStream.Close()',
  '      $byBreak="request"; break',
  '    }',
  '    else{',
  '      $res.ContentType="text/html; charset=utf-8"',
  '      $res.Headers.Add("Cache-Control","no-store")',
  '      $res.ContentLength64=$html.Length',
  '      $res.OutputStream.Write($html,0,$html.Length)',
  '    }',
  '    $res.OutputStream.Close()',
  '  }catch{ Start-Sleep -Milliseconds 50 }',
  '}',
  '$h.Stop()',
  'try{ Add-Content $srvLog ("stop "+$byBreak+" "+(Get-Date -Format s)) }catch{ }',
  '}catch{',
  '  $d=Join-Path $env:LOCALAPPDATA ''img2pixel''',
  '  if(!(Test-Path $d)){ New-Item -ItemType Directory -Path $d -Force | Out-Null }',
  '  [IO.File]::WriteAllText((Join-Path $d ''boot-error.log''), ($_ | Out-String))',
  '}',
  ''
)
$ps=($psLines -join $nl)

# ---------- inject the embedded icon as base64 ----------
$q=[char]39
$icoLine='$I2P_ICO_B64='+$q+[Convert]::ToBase64String([IO.File]::ReadAllBytes($ico))+$q
$ps=$ps.Replace('@ICO@',$icoLine)
if(-not $ps.Contains('$I2P_ICO_B64')){ throw 'ICO injection failed' }

# ---------- assemble ----------
$content = $pre
$content += '#I2P_PS_START#'+$nl + $ps + $nl
$content += '#I2P_PS_END#'+$nl
$content += '#I2P_HTML_START#'+$nl + $html + $nl
$content += '#I2P_HTML_END#'+$nl
[IO.File]::WriteAllText($out,$content,[Text.UTF8Encoding]::new($false))

$size=(Get-Item $out).Length
Write-Host "OK: $out ($size bytes)"
