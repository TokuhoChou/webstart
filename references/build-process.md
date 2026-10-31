# How the launcher evolved in the original project

This case study records the useful decisions and failures from the original
Codex chat. Use the principles, not the project-specific names.

## 1. A local-only server had to become LAN-accessible

The first website server bound to loopback. Other devices could not connect even
when the browser URL worked on the host. The implementation was changed to:

- bind `0.0.0.0` by default;
- keep `PORT` and `HOST` configurable;
- detect non-internal IPv4 addresses;
- print both `http://127.0.0.1:<port>/` and candidate LAN URLs;
- open the browser after the server started.

On the original network, the LAN URL used a private `192.168.x.x` address and
was tested from the host through that address. The local and LAN routes both
returned HTTP 200.

## 2. The first launcher was too large for batch

The first `启动局域网网站.cmd` started Node directly. It then grew into a complete
menu with Chinese labels and `goto` branches. A real Windows test exposed the
critical failure: under the active code page, Chinese batch input was truncated
before the expected command could run.

The lesson is structural:

- `.cmd` is only a launcher shell;
- PowerShell owns functions, polling, Chinese input, and branching;
- keep the `.cmd` wrapper small and ASCII-safe.
- save a Chinese PowerShell script as UTF-8 with BOM for Windows PowerShell 5.1.

Moving the logic to `site-console.ps1` made `状态`, `关闭`, and `开启` independently
testable and removed the batch parsing failure. A later compatibility check also
proved that the PowerShell file must retain its UTF-8 BOM. Without the BOM,
Windows PowerShell 5.1 can read the file under the active ANSI code page, corrupt
the Chinese literals, and report parser errors before the menu even appears.

## 3. Repeated startup produced `EADDRINUSE`

Clicking the launcher twice caused a second server process to fail because port
4173 was already owned by the first process. The user correctly perceived this
as a broken startup experience.

The server was changed to inspect `EADDRINUSE` and probe the existing page. If
the response matched this website, it reopened the existing URL and exited
successfully instead of starting a duplicate. The robust version should also
compare a stable `appId` through the status endpoint; matching only a generic
HTTP response can mistake another local app for the target.

## 4. Port-based process killing was rejected

The first close workflow found the listener on 4173 and terminated its owning
PID. That worked in the narrow test, but it is unsafe on a general-purpose
machine: another application can legitimately own the port or the user may have
changed the configured port.

The final design moves shutdown into the website server:

- `POST /__control/shutdown` asks this exact server to stop;
- the endpoint is loopback-only;
- LAN callers receive `403`;
- the console polls until the matching status endpoint disappears.

This avoids process discovery and eliminates broad process termination.

## 5. One console replaced separate start and close files

The user explicitly asked for one file where they could type `开启` or `关闭`.
The working solution used one `.cmd` wrapper and one PowerShell controller:

```text
启动局域网网站.cmd
        |
        +-- opens site-console.ps1 in the same window
                    |
                    +-- 开启 / 关闭 / 地址 / 状态 / 退出
                    |
                    +-- localhost control API
                                  |
                                  +-- website server
```

`退出` closes only the console. The server remains available until `关闭` is
entered, which makes the distinction between navigation and service lifetime
clear.

## 6. The server control routes were deliberately narrow

The implemented control routes:

- appear before the static-file handler;
- accept only loopback clients;
- require `GET` for status and `POST` for shutdown;
- return JSON for status;
- send the shutdown acknowledgement before closing the listener.

This keeps the normal website accessible over LAN while preventing a phone on
the same network from stopping it.

## What survived as the reusable design

Retain these decisions for similar projects:

1. One visible console and five predictable commands.
2. Server-owned shutdown rather than port-wide process termination.
3. A heavy PowerShell controller behind a tiny batch wrapper.
4. UTF-8 BOM on every Chinese Windows PowerShell 5.1 script.
5. Bounded polling with user-facing success and failure states.
6. Local and LAN addresses displayed from live network interfaces.
7. Repeated launch reuses the existing site.
8. Tests run with browser opening disabled.
9. Documentation explains that the server outlives the console.

Do not blindly copy the original project's site name, hard-coded port, HTML
marker, or Chinese aliases. Re-derive those from the current project.
