---
name: webstart
description: Build or repair a Windows local/LAN website launcher with a Chinese command console, safe start/stop/status behavior, and localhost-only control endpoints. Use for double-click local website startup; do not use for cloud deployment or general web design.
metadata:
  short-description: 可靠的 Windows 本地与局域网网站启动控制台
---

# WebStart

Create a project-local startup experience that a non-developer can use by
double-clicking one file. The finished launcher controls one website process,
shows local and LAN addresses, tolerates repeated launches, and stops only the
matching site.

Use this skill for Windows websites served from the user's computer (often a
Node local server) when the user asks for a launcher, LAN access, a Chinese
start/stop console, or a safer replacement for a fragile `.cmd` file.

## Target shape

Prefer this separation:

1. The website server owns health and shutdown behavior.
2. A one-purpose `.cmd` file opens the PowerShell console in the same window.
3. `site-console.ps1` implements the Chinese menu and all state transitions.
4. Browser opening has one owner, so a new launch opens one tab and a repeated
   launch reopens the existing site.
5. The server continues running when the console exits, and `关闭` stops it
   through the server's own localhost-only control endpoint.

Do not kill a process merely because it owns the configured port. That can stop
an unrelated application.

## Inspect first

Before editing:

- Identify the real server entry point, runtime command, documented port, and
  project root.
- Read the existing server routing and launcher files. Preserve unrelated
  behavior and existing user-authored names.
- Choose a stable `appId` or HTML marker that proves a process is this site.
- Check whether the server already opens a browser. Keep exactly one browser
  owner rather than opening both from the server and the console.
- Decide whether the control surface belongs in the existing framework server
  or an equivalent local wrapper. Do not add a build tool or dependency just
  for start/stop control.

## Implement the server contract

For a Node server, implement the equivalent of the following contract. Adapt
paths and response fields to the project, but keep their semantics.

### Network binding

- Default to `HOST=0.0.0.0` and a configurable `PORT` when LAN access is wanted.
- Print the loopback URL and each usable LAN IPv4 URL after listening.
- Avoid treating every network-interface address as reachable merely because it
  exists. Present LAN URLs as candidates and mention Wi-Fi/firewall isolation in
  the README.
- Support `OPEN_BROWSER=0` so automated tests do not open tabs. If the server
  opens the browser, open it only after a successful listen.

### Local control endpoint

- Add `GET /__control/status` and `POST /__control/shutdown`.
- Handle these routes before static files, SPA fallbacks, or catch-all routes.
- Accept them only when `request.socket.remoteAddress` is loopback. Account for
  `127.0.0.1`, `::1`, and IPv4-mapped `::ffff:127.0.0.1`.
- Return `403` to LAN callers, `405` for the wrong method, and JSON with
  `Cache-Control: no-store`.
- Make status include at least `ok`, `running`, `appId`, `pid`, `port`,
  `localUrl`, and `lanUrls`.
- On shutdown, send the JSON response first, then close the server shortly
  afterward and exit. Do not close the socket before the console receives the
  acknowledgement.
- If the project needs protection from other local web pages, add a per-run
  token or strict Origin validation. The loopback check alone is a network
  boundary, not a complete browser-origin policy.

### Port conflict

When `EADDRINUSE` occurs:

- Probe the status endpoint and compare `appId` before declaring that this site
  is already running.
- If it is the same app, print its URLs and open/reuse it without starting a
  duplicate process.
- If the endpoint is absent or belongs to another app, report the conflict in
  plain language. Do not terminate the occupant.

See [references/build-process.md](references/build-process.md) for the real
failure sequence that led to this design.

## Build the Windows console

Use the starter files in
[assets/windows-launcher](assets/windows-launcher) when they fit the project,
then replace their site name, `appId`, port, and server script.

### `.cmd` wrapper

Keep the batch file deliberately small:

```bat
@echo off
setlocal
cd /d "%~dp0"
title Site Console
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0site-console.ps1"
if errorlevel 1 pause
```

Do not put Chinese branching, loops, or long inline PowerShell in batch.
Windows code-page conversion can corrupt or truncate those commands.

### PowerShell console

Implement these behaviors in `site-console.ps1`:

- Save the file as **UTF-8 with BOM** when it contains Chinese. Windows
  PowerShell 5.1 may otherwise interpret it as the active ANSI code page and
  fail to parse the Chinese strings.
- Resolve the script directory and `Set-Location` there so double-clicking and
  automation use the same working directory.
- Read status with `Invoke-RestMethod` and a short timeout.
- Enumerate active, non-loopback IPv4 addresses with
  `System.Net.NetworkInformation.NetworkInterface`.
- `开启`: reuse a matching running site; otherwise verify the runtime, start the
  server hidden in the correct directory, poll status for a bounded time, and
  report success only after a matching status response.
- `关闭`: send `POST` to the matching control endpoint, then poll until status
  disappears. Never use `Stop-Process` on an arbitrary process that happens to
  own the port.
- `地址`: show loopback and LAN URLs plus the same-network instruction.
- `状态`: show whether this site is running and its PID.
- `退出`: leave the server running and explain that fact.
- Route Chinese aliases and optional numeric shortcuts through one
  `Invoke-ConsoleCommand` function.
- Accept `-Command <text>` for non-interactive tests while keeping the default
  interactive menu.
- Honor `OPEN_BROWSER=0` in tests.

Use the full template at
[assets/windows-launcher/site-console.ps1](assets/windows-launcher/site-console.ps1).
Keep its UTF-8 BOM when copying or editing it; a byte-for-byte encoding check is
part of the verification recipe.

## Documentation

Update the project README with:

- The exact double-click entry point.
- The five commands and what `退出` does versus `关闭`.
- The default local URL and how LAN access works.
- The Windows Firewall private-network setting.
- The fact that closing the browser tab does not stop the server.

## Verify

Run the checks in
[references/verification.md](references/verification.md). At minimum, prove:

- JavaScript syntax and PowerShell parsing pass.
- New start, duplicate start, status, stop, and restart all behave correctly.
- The loopback page and an active LAN URL return the site.
- A control request addressed through the LAN IP is rejected.
- No unrelated process is killed.

Leave the website running at the end only when the user asked to use it now;
otherwise stop the test instance.
