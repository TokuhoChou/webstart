param(
    [string]$Command = ""
)

# Replace these values when adapting the template.
$siteName = "Website"
$appId = "replace-with-a-stable-site-id"
$port = 4173
$serverScript = "server.mjs"
$nodeCommandName = "node"

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptRoot
try { $Host.UI.RawUI.WindowTitle = "$siteName 网站控制台" } catch {}

$baseUrl = "http://127.0.0.1:$port"
$statusUrl = "$baseUrl/__control/status"
$shutdownUrl = "$baseUrl/__control/shutdown"

function Get-SiteStatus {
    try {
        $status = Invoke-RestMethod -Uri $statusUrl -TimeoutSec 2
        if ($status.running -and $status.appId -eq $appId) {
            return $status
        }
        return $null
    }
    catch {
        return $null
    }
}

function Get-LanUrls {
    $addresses = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
        Where-Object {
            $_.OperationalStatus -eq "Up" -and
            $_.NetworkInterfaceType -ne "Loopback"
        } |
        ForEach-Object {
            $_.GetIPProperties().UnicastAddresses |
                Where-Object {
                    $_.Address.AddressFamily -eq "InterNetwork" -and
                    -not $_.Address.IPAddressToString.StartsWith("169.254.")
                } |
                ForEach-Object { $_.Address.IPAddressToString }
        } |
        Sort-Object -Unique

    return @($addresses | ForEach-Object { "http://${_}:$port/" })
}

function Show-Addresses {
    Write-Host ""
    Write-Host "网站地址：" -ForegroundColor Cyan
    Write-Host "  本机：     $baseUrl/"

    $lanUrls = Get-LanUrls
    if ($lanUrls.Count -gt 0) {
        Write-Host "  局域网："
        foreach ($url in $lanUrls) {
            Write-Host "             $url"
        }
        Write-Host ""
        Write-Host "手机、平板或其他电脑需要连接同一个 Wi-Fi。" -ForegroundColor DarkGray
    }
    else {
        Write-Host "  局域网：     暂未检测到可用地址"
    }
}

function Open-Site {
    if ($env:OPEN_BROWSER -ne "0") {
        Start-Process "$baseUrl/"
    }
}

function Start-Site {
    $status = Get-SiteStatus
    if ($status) {
        Write-Host "网站已经在运行，正在打开现有网页……" -ForegroundColor Yellow
        Open-Site
        Show-Addresses
        return
    }

    $node = Get-Command $nodeCommandName -ErrorAction SilentlyContinue
    if (-not $node) {
        Write-Host "没有找到 Node.js，请先安装并确认 node 命令可用。" -ForegroundColor Red
        return
    }

    Write-Host "正在启动网站……" -ForegroundColor Yellow
    $serverProcess = Start-Process -FilePath $node.Source `
        -ArgumentList $serverScript `
        -WorkingDirectory $scriptRoot `
        -WindowStyle Hidden `
        -PassThru

    $status = $null
    for ($attempt = 0; $attempt -lt 12; $attempt += 1) {
        Start-Sleep -Milliseconds 350
        $status = Get-SiteStatus
        if ($status) { break }
        if ($serverProcess.HasExited) { break }
    }

    if ($status) {
        Write-Host "网站开启成功。" -ForegroundColor Green
        # The server opens a new browser by default. Remove this call if your
        # server does not open the browser itself.
        Show-Addresses
    }
    else {
        Write-Host "网站启动失败。" -ForegroundColor Red
        Write-Host "请检查 Node.js 和服务器报错，并确认端口 $port 是否被其他程序占用。"
    }
}

function Stop-Site {
    $status = Get-SiteStatus
    if (-not $status) {
        Write-Host "网站当前没有运行。" -ForegroundColor Yellow
        return
    }

    Write-Host "正在关闭网站……" -ForegroundColor Yellow
    try {
        Invoke-RestMethod -Method Post -Uri $shutdownUrl -TimeoutSec 4 | Out-Null
        for ($attempt = 0; $attempt -lt 15; $attempt += 1) {
            Start-Sleep -Milliseconds 250
            if (-not (Get-SiteStatus)) {
                Write-Host "网站已经关闭。" -ForegroundColor Green
                return
            }
        }
        Write-Host "关闭请求已发送，但网站仍在运行。" -ForegroundColor Red
    }
    catch {
        Write-Host "网站关闭失败，请检查服务器窗口或日志。" -ForegroundColor Red
    }
}

function Show-SiteStatus {
    $status = Get-SiteStatus
    if ($status) {
        Write-Host "网站状态：正在运行" -ForegroundColor Green
        Write-Host "进程 PID：$($status.pid)"
    }
    else {
        Write-Host "网站状态：没有运行" -ForegroundColor Yellow
    }
    Show-Addresses
}

function Invoke-ConsoleCommand {
    param([string]$Text)

    switch ($Text.Trim().ToLowerInvariant()) {
        "开启" { Start-Site; return $true }
        "打开" { Start-Site; return $true }
        "1" { Start-Site; return $true }
        "关闭" { Stop-Site; return $true }
        "关" { Stop-Site; return $true }
        "2" { Stop-Site; return $true }
        "地址" { Show-Addresses; return $true }
        "链接" { Show-Addresses; return $true }
        "3" { Show-Addresses; return $true }
        "状态" { Show-SiteStatus; return $true }
        "4" { Show-SiteStatus; return $true }
        "退出" { return $false }
        "0" { return $false }
    }

    Write-Host "无法识别该命令，请输入：开启、关闭、地址、状态或退出。" -ForegroundColor Red
    return $true
}

if ($Command) {
    Invoke-ConsoleCommand -Text $Command | Out-Null
    exit 0
}

$running = $true
while ($running) {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor DarkGray
    Write-Host "           $siteName 网站控制台" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "可输入的中文命令：" -ForegroundColor Cyan
    Write-Host "  开启    启动网站，并自动打开浏览器"
    Write-Host "  关闭    停止正在运行的网站"
    Write-Host "  地址    显示本机和局域网访问链接"
    Write-Host "  状态    查看网站是否正在运行"
    Write-Host "  退出    退出控制台（网站继续运行）"
    Write-Host ""
    Show-Addresses
    Write-Host ""

    $inputCommand = Read-Host "请输入命令（开启/关闭/地址/状态/退出）"
    $running = Invoke-ConsoleCommand -Text $inputCommand

    if ($running) {
        Write-Host ""
        Read-Host "按回车键返回命令菜单" | Out-Null
    }
}

Clear-Host
Write-Host ""
Write-Host "已退出网站控制台。"
Write-Host "网站服务器如果没有执行“关闭”，会继续运行。"
Write-Host "下次打开启动器，输入“关闭”即可停止它。"
Write-Host ""
