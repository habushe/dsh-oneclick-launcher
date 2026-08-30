# dsh-oneclick-launcher — GitHub 发布脚本
# ----------------------------------------
# 这个脚本会：
#   1. 用 GitHub API 创建仓库 dsh-oneclick-launcher
#   2. 上传仓库内的所有文件
#   3. 给仓库添加 dsh-plugin 话题
#   4. 输出一份可直接粘贴到官方 Discussions 的帖子文本
#
# 使用方法：
#   1. 在 GitHub 创建 Personal Access Token:
#      Settings -> Developer settings -> Personal access tokens -> Tokens (classic)
#      勾选 repo 权限
#   2. 设置环境变量（PowerShell）:
#      $env:GH_USER = "你的用户名"
#      $env:GH_TOKEN = "你的token"
#   3. 运行:
#      powershell -ExecutionPolicy Bypass -File .\publish.ps1
#
# 代理：如果使用 Clash Verge 等代理，脚本会自动读取系统代理设置；
#       也可手动设置 $env:HTTPS_PROXY = "http://127.0.0.1:7897"

$ErrorActionPreference = "Stop"

# ---------- 0. config ----------
$user = $env:GH_USER
$token = $env:GH_TOKEN
if (-not $user -or -not $token) {
    Write-Host "ERROR: 请先设置环境变量 GH_USER 和 GH_TOKEN" -ForegroundColor Red
    Write-Host '  $env:GH_USER = "你的GitHub用户名"' -ForegroundColor Yellow
    Write-Host '  $env:GH_TOKEN = "你的token"' -ForegroundColor Yellow
    exit 1
}

$repoName = "dsh-oneclick-launcher"
$repoDesc = "Windows one-click launcher for DeepSeek Harness: standalone PWA window, no browser tab"
$apiBase = "https://api.github.com"
$headers = @{
    Authorization = "token $token"
    "User-Agent"  = "dsh-oneclick-launcher-publisher"
    Accept        = "application/vnd.github+json"
}

# Proxy: read from env or try system proxy
$proxy = $env:HTTPS_PROXY
if (-not $proxy) {
    $ie = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
    if ($ie.ProxyEnable -eq 1 -and $ie.ProxyServer) { $proxy = "http://$($ie.ProxyServer)" }
}
if ($proxy) { Write-Host "Using proxy: $proxy" -ForegroundColor DarkGray }

$api = { param($method, $url, $body)
    $params = @{ Method = $method; Uri = $url; Headers = $headers; UseBasicParsing = $true; TimeoutSec = 30 }
    if ($body) { $params.Body = ($body | ConvertTo-Json -Depth 10); $params.ContentType = "application/json" }
    if ($proxy) { $params.Proxy = $proxy }
    try { Invoke-RestMethod @params } catch {
        $resp = $_.Exception.Response
        if ($resp) {
            $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
            $err = $reader.ReadToEnd()
            Write-Host "API Error ($($resp.StatusCode)): $err" -ForegroundColor Red
        } else {
            Write-Host "API Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        throw
    }
}

# ---------- 1. create repo ----------
Write-Host "`n=== 1. 创建仓库 $repoName ===" -ForegroundColor Cyan
$createBody = @{
    name        = $repoName
    description = $repoDesc
    private     = $false
    auto_init   = $true
}
$repo = & $api "POST" "$apiBase/user/repos" $createBody
Write-Host "仓库创建成功: $($repo.html_url)" -ForegroundColor Green

# ---------- 2. upload files ----------
Write-Host "`n=== 2. 上传文件 ===" -ForegroundColor Cyan
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$files = @(
    "README.md",
    "DeepSeekHarnessLauncher.vbs",
    "install.ps1",
    "LICENSE",
    ".gitignore"
)
foreach ($f in $files) {
    $path = Join-Path $scriptDir $f
    if (-not (Test-Path $path)) { Write-Host "跳过(不存在): $f" -ForegroundColor DarkGray; continue }
    $content = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($path))
    # 更新已有文件必须带 sha；GET 返回 404 说明是新文件
    $sha = ""
    $msg = "Add $f"
    try {
        $existing = & $api "GET" "$apiBase/repos/$user/$repoName/contents/$f"
        $sha = $existing.sha
        $msg = "Update $f (v7 sync)"
    } catch { $msg = "Add $f" }
    $body = @{
        message = $msg
        content = $content
    }
    if ($sha) { $body.sha = $sha }
    try {
        & $api "PUT" "$apiBase/repos/$user/$repoName/contents/$f" $body
        Write-Host "上传成功: $f ($msg)" -ForegroundColor Green
    } catch { Write-Host "上传失败: $f" -ForegroundColor Red }
}

# ---------- 3. add topics ----------
Write-Host "`n=== 3. 设置 dsh-plugin 话题 ===" -ForegroundColor Cyan
try {
    $topicBody = @{ names = @("dsh-plugin", "deepseek-harness", "windows", "launcher") }
    $params = @{ Method = "PUT"; Uri = "$apiBase/repos/$user/$repoName/topics"; Headers = $headers; UseBasicParsing = $true; TimeoutSec = 30; ContentType = "application/json" }
    if ($proxy) { $params.Proxy = $proxy }
    $params.Body = ($topicBody | ConvertTo-Json -Depth 5)
    Invoke-RestMethod @params | Out-Null
    Write-Host "话题已设置: dsh-plugin, deepseek-harness, windows, launcher" -ForegroundColor Green
} catch { Write-Host "话题设置失败（不影响仓库）" -ForegroundColor Yellow }

# ---------- 4. output discussion post ----------
Write-Host "`n=== 4. 生成 Discussions 帖子文本 ===" -ForegroundColor Cyan
$postPath = Join-Path $scriptDir "DISCUSSION_POST.md"
if (Test-Path $postPath) {
    $post = Get-Content $postPath -Raw
    # replace placeholder username
    $post = $post.Replace("<your-username>", $user)
    $outPath = Join-Path $scriptDir "DISCUSSION_POST_READY.md"
    [System.IO.File]::WriteAllText($outPath, $post, [System.Text.Encoding]::UTF8)
    Write-Host "帖子文本已生成: $outPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== 下一步：发布到官方 Discussions ===" -ForegroundColor Cyan
    Write-Host "1. 打开: https://github.com/deepseek-ai/deepseek-harness/discussions" -ForegroundColor White
    Write-Host "2. 点击 New discussion" -ForegroundColor White
    Write-Host "3. 选择合适分类（如 Show and tell / General）" -ForegroundColor White
    Write-Host "4. 把 $outPath 的内容粘贴进去发布" -ForegroundColor White
} else {
    Write-Host "未找到 DISCUSSION_POST.md" -ForegroundColor Yellow
}

Write-Host "`n=== 完成！仓库地址: https://github.com/$user/$repoName ===" -ForegroundColor Cyan
