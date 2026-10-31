# Verification recipe

Use the project's actual runtime and port. Replace the example names below.
Do not leave test browser windows or processes behind unless the user asked for
the site to stay running.

## 1. Static checks

For Node:

```powershell
node --check server.mjs
```

For a Chinese PowerShell 5.1 script, first confirm UTF-8 BOM bytes
`EF BB BF`:

```powershell
$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path '.\site-console.ps1'))
if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
  throw 'site-console.ps1 must be UTF-8 with BOM'
}
```

Then parse it with the same Windows PowerShell executable used by the `.cmd`
wrapper. Do not validate only with PowerShell 7, because PowerShell 7 defaults
to UTF-8 and can hide a Windows PowerShell 5.1 encoding failure:

```powershell
powershell.exe -NoProfile -Command @'
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  (Resolve-Path '.\site-console.ps1'),
  [ref]$tokens,
  [ref]$errors
) | Out-Null
if ($errors.Count -gt 0) { $errors | Format-List; exit 1 }
'@
```

## 2. Start through the real console path

Set `OPEN_BROWSER=0` for automation, then invoke the console command mode:

```powershell
$env:OPEN_BROWSER = '0'
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File '.\site-console.ps1' -Command 开启
```

Confirm the process does not exit immediately and that status contains the
expected `appId`, `pid`, `port`, `localUrl`, and `lanUrls`.

## 3. Test HTTP behavior

Test loopback:

```powershell
$local = Invoke-WebRequest 'http://127.0.0.1:4173/' -UseBasicParsing
$local.StatusCode
```

Test the first reachable LAN candidate:

```powershell
$status = Invoke-RestMethod 'http://127.0.0.1:4173/__control/status'
$status.lanUrls
foreach ($url in $status.lanUrls) {
  try {
    (Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 4).StatusCode
  } catch {
    "Not reachable from this interface: $url"
  }
}
```

At least one LAN candidate should return the site when the machine has a usable
private network. A virtual adapter or isolated interface may not be reachable.

Verify control is loopback-only by sending the request through a LAN address:

```powershell
try {
  Invoke-RestMethod 'http://192.168.1.10:4173/__control/status' -TimeoutSec 4
  throw 'LAN control request unexpectedly succeeded'
} catch {
  if ($_.Exception.Response.StatusCode.value__ -ne 403) { throw }
}
```

Use the current machine's real LAN address, not the example.

## 4. Test repeated launch

Run `-Command 开启` a second time. It must:

- complete successfully;
- not leave a second listener;
- identify the existing PID;
- open/reuse the same site without a raw `EADDRINUSE` error.

## 5. Test stop and restart

Run `-Command 关闭`, then immediately query status. The request should fail
because the listener is gone. Start again and repeat once to catch state that
only appears after shutdown cleanup.

## 6. Interactive smoke test

Use the real `.cmd` file in a terminal that accepts Chinese input. Type:

```text
状态
关闭
开启
退出
```

The menu must remain readable, each Chinese command must be recognized, and
exit must leave the server running with a clear explanation.

## 7. Final state

- If the user wants to browse now, leave the server running and provide the
  verified local and LAN URLs.
- Otherwise enter `关闭` and confirm the status endpoint is unavailable.
- Report any interface that could not be reached instead of claiming every
  printed LAN address works.
