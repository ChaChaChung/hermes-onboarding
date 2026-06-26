# ============================================================
# Hermes Agent 安裝邏輯 (Windows / PowerShell)
# 由 hermes-setup.iss 在安裝過程中呼叫，也可以單獨手動執行測試：
#   powershell -ExecutionPolicy Bypass -File run-onboarding.ps1 -ProfileRepo "github.com/你/你的repo" -ProfileAlias "myagent"
# ============================================================

param(
    [Parameter(Mandatory = $true)][string]$ProfileRepo,
    [Parameter(Mandatory = $true)][string]$ProfileAlias
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Write-Warn($msg) {
    Write-Host $msg -ForegroundColor Yellow
}

# ------------------------------------------------------------------
# 步驟 1：跑官方安裝腳本
# 會裝好 Python 3.11+、Node.js、ripgrep、ffmpeg、一份 portable Git，
# 以及 hermes CLI 本體。官方原生 Windows 安裝路徑是 %LOCALAPPDATA%\hermes。
# ------------------------------------------------------------------
Write-Step "安裝 Hermes Agent 核心..."
try {
    Invoke-RestMethod https://hermes-agent.nousresearch.com/install.ps1 | Invoke-Expression
} catch {
    Write-Warn "官方安裝腳本執行失敗：$($_.Exception.Message)"
    Write-Warn "請確認使用者電腦有網路連線後再試一次。"
    exit 1
}

# ------------------------------------------------------------------
# 步驟 2：找出 hermes 執行檔
# 同一個 process 裡剛裝完，PATH 環境變數可能還沒刷新，
# 這裡同時嘗試已知安裝路徑跟重新讀取系統 PATH 兩種方式。
#
# 注意：下面列出的路徑是依官方文件推測的常見安裝位置，
# 正式量產發布前，請務必在一台乾淨的 Windows 機器上實際跑一次，
# 確認路徑跟你環境裡的實際情況一致，必要時自行調整。
# ------------------------------------------------------------------
Write-Step "尋找 hermes 執行檔..."

$hermesExe = $null
$candidatePaths = @(
    "$env:LOCALAPPDATA\hermes\bin\hermes.exe",
    "$env:LOCALAPPDATA\hermes\hermes.exe"
)

foreach ($p in $candidatePaths) {
    if (Test-Path $p) {
        $hermesExe = $p
        break
    }
}

if (-not $hermesExe) {
    # 退而求其次：重新整理目前 process 的 PATH，再用 Get-Command 找
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"

    $found = Get-Command hermes -ErrorAction SilentlyContinue
    if ($found) { $hermesExe = $found.Source }
}

if (-not $hermesExe) {
    Write-Warn "找不到 hermes 執行檔。可能是安裝路徑跟預期不同，"
    Write-Warn "或剛裝完的環境變數還沒生效。"
    Write-Warn "使用者可以關閉這個視窗，重新開一個終端機後手動執行："
    Write-Warn "  hermes profile install $ProfileRepo --alias -y"
    exit 1
}

Write-Host "找到 hermes：$hermesExe"

# ------------------------------------------------------------------
# 步驟 3：套用你的 Profile Distribution
# 裡面已經內建 proxy base_url 等設定，-y 代表不需要互動確認，
# --alias 會額外建立一個指令別名（例如 myagent chat / myagent desktop）
# ------------------------------------------------------------------
Write-Step "安裝你的專屬設定（Profile Distribution: $ProfileRepo）..."
try {
    # --force：同名 profile 已存在時覆蓋設定檔，但保留使用者 .env / 金鑰 / 對話紀錄，
    # 讓安裝程式可安全重複執行（重裝、更新都不會失敗）。
    & $hermesExe profile install $ProfileRepo --name $ProfileAlias --alias --force -y
} catch {
    Write-Warn "安裝 Profile Distribution 失敗：$($_.Exception.Message)"
    Write-Warn "請確認 $ProfileRepo 這個 git repo 使用者電腦上能存取到（公開 repo，或已設定好 git 認證）。"
    exit 1
}

# ------------------------------------------------------------------
# 金鑰引導：這份 distribution 需要使用者自己的 AITOKENKING_API_KEY。
# 安裝完 .env 是空的（只有 .env.EXAMPLE 範本），若不填金鑰，
# Hermes 一對話就會報金鑰錯誤。這裡幫使用者把 .env 準備好、打開、並印出說明。
# ------------------------------------------------------------------
$hermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { Join-Path $env:USERPROFILE ".hermes" }
$profileDir = Join-Path $hermesHome "profiles\$ProfileAlias"
$envFile    = Join-Path $profileDir ".env"
$envExample = Join-Path $profileDir ".env.EXAMPLE"

# 若還沒有 .env，就用範本複製一份出來給使用者填
if ((-not (Test-Path $envFile)) -and (Test-Path $envExample)) {
    Copy-Item $envExample $envFile
}

# 偵測金鑰是否已填（環境變數已設、或 .env 裡 AITOKENKING_API_KEY= 後面有值）
$keySet = $false
if ($env:AITOKENKING_API_KEY) {
    $keySet = $true
} elseif ((Test-Path $envFile) -and (Select-String -Path $envFile -Pattern '^\s*AITOKENKING_API_KEY=\S+' -Quiet)) {
    $keySet = $true
}

if (-not $keySet) {
    # 自動用記事本打開 .env，讓使用者直接貼金鑰
    if (Test-Path $envFile) { Start-Process notepad $envFile }
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
    Write-Host "⚠️  最後一步：填入你的 API 金鑰才能使用" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   1. 已為你打開設定檔（若沒自動打開請手動編輯）："
    Write-Host "      $envFile"
    Write-Host "   2. 找到這一行，把金鑰貼在 = 後面："
    Write-Host "      AITOKENKING_API_KEY="
    Write-Host "   3. 存檔後，重新開啟 Hermes Desktop 即可使用。"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
}

# ------------------------------------------------------------------
# 步驟 4：啟動桌面 App，讓使用者打開時看到的就是已經接好的聊天視窗
# ------------------------------------------------------------------
Write-Step "啟動 Hermes Desktop..."
Start-Process -FilePath $hermesExe -ArgumentList "desktop", "-p", $ProfileAlias

Write-Host ""
Write-Host "完成！" -ForegroundColor Green
