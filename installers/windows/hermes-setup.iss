; ============================================================
; Hermes Agent 一鍵安裝精靈 (Windows)
; ============================================================
; 這個安裝包做兩件事：
;   1. 在背景跑官方的 Hermes Agent 安裝腳本
;      （裝好 Python / Node.js / git / ripgrep / ffmpeg 等執行環境 + hermes CLI 本體）
;   2. 安裝完成後，自動套用你預先準備好的 Profile Distribution
;      （裡面已經內建你的 aitokenking proxy base_url、SOUL.md 等設定）
;
; 使用前請先修改下面「請依需求修改」區塊，並把同目錄的
; run-onboarding.ps1 留在一起，不要分開。
;
; 打包方式：
;   1. 安裝 Inno Setup（免費）：https://jrsoftware.org/isinfo.php
;   2. 用 Inno Setup 打開這個 .iss 檔
;   3. 按上方選單 Build → Compile
;   4. 編譯完成的 .exe 會出現在 Output 資料夾
;
; 強烈建議：編譯出來的 .exe 請用你自己的 code-signing 憑證簽名
; （例如用 signtool.exe），否則 Windows SmartScreen 會跳出
; 「Windows 已保護您的電腦 / 未知發行者」的警告，使用者體感很差。
; ============================================================

#define MyAppName "你的產品名稱 Hermes 助理"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "你的公司名稱"

; ──────────────── 請依需求修改 ────────────────
; 你的 Profile Distribution git repo（前面討論的那份內建 proxy 設定的 repo）
#define MyProfileRepo "github.com/你的帳號/你的profile-repo"
; 安裝完成後要建立的指令別名，使用者之後可以直接打 "myagent chat" 或 "myagent desktop"
#define MyProfileAlias "myagent"
; ───────────────────────────────────────────────

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\HermesOnboarding
DisableProgramGroupPage=yes
OutputBaseFilename={#MyAppName}-Setup
Compression=lzma
SolidCompression=yes
; 不需要系統管理員權限——Hermes 官方安裝走的是 per-user 安裝
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible

[Files]
; 把 PowerShell 腳本一起塞進安裝包，裝完即刪
Source: "run-onboarding.ps1"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]
; 真正的安裝邏輯都寫在 run-onboarding.ps1 裡執行
; -WindowStyle Normal 讓使用者看得到進度，方便除錯；上線後可改成 Hidden
Filename: "powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File ""{tmp}\run-onboarding.ps1"" -ProfileRepo ""{#MyProfileRepo}"" -ProfileAlias ""{#MyProfileAlias}"""; \
    StatusMsg: "正在安裝 Hermes Agent 與你的專屬設定，請稍候（需要網路連線，約 2-5 分鐘）..."; \
    Flags: runascurrentuser waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\HermesOnboarding"
