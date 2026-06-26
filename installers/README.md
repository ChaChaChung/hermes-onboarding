# Hermes Agent 一鍵安裝包範本

這套範本做的事很單純：在使用者電腦上依序執行兩步驟——

1. 跑 Hermes Agent 官方安裝腳本（裝 Python/Node/git 等環境 + hermes CLI 本體，這部分永遠交給 Nous Research 自己維護更新）
2. 套用你的 **Profile Distribution**（之前討論過的那份 git repo，裡面已經內建你的 aitokenking proxy `base_url`、SOUL.md 等設定）

完成後使用者打開的就是已經接好你 proxy 的 Hermes Desktop，不需要自己手動編輯任何設定檔。

---

## 開始之前：先填好這些設定值

兩個平台的腳本裡都有一段「請依需求修改」的區塊，至少要改：

| 變數 | 說明 |
|---|---|
| `ProfileRepo` / `PROFILE_REPO` | 你的 Profile Distribution git repo，例如 `github.com/你的帳號/你的repo` |
| `ProfileAlias` / `PROFILE_ALIAS` | 安裝後的指令別名，例如 `myagent`（之後使用者可以打 `myagent chat`） |

Windows 版額外要改 `hermes-setup.iss` 裡的 `MyAppName`、`MyAppPublisher`。
macOS 用 `.pkg` 包裝的話，要改 `build-pkg.sh` 裡的 `IDENTIFIER`。

---

## Windows：`windows/` 資料夾

包含兩個檔案，**要放在同一個資料夾**：
- `hermes-setup.iss` — Inno Setup 的安裝包定義檔
- `run-onboarding.ps1` — 實際的安裝邏輯（會被打包進 exe，安裝時執行）

### 打包步驟

1. 安裝 [Inno Setup](https://jrsoftware.org/isinfo.php)（免費）
2. 用 Inno Setup 打開 `hermes-setup.iss`
3. 選單 **Build → Compile**
4. 編譯完成的 `.exe` 會在 `Output/` 資料夾裡

### 簽名（強烈建議）

沒簽名的話，使用者執行時 Windows SmartScreen 會跳出「Windows 已保護您的電腦」的警告，看起來很像病毒。如果你有 code-signing 憑證：

```powershell
signtool sign /f 你的憑證.pfx /p 憑證密碼 /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 "Output\你的產品名稱-Setup.exe"
```

---

## macOS：`macos/` 資料夾

包含兩個檔案：
- `hermes-onboarding-macos.sh` — 實際的安裝邏輯
- `build-pkg.sh` — 把上面那個腳本包成正式的 `.pkg` 安裝包

### 方式 A：最簡單，但比較不正式

把 `hermes-onboarding-macos.sh` 改名成 `安裝 Hermes.command`，執行：

```bash
chmod +x "安裝 Hermes.command"
```

直接把這個檔案發給使用者，雙擊執行（會跳出一個 Terminal 視窗跑安裝過程）。

缺點：看起來像在開終端機腳本，不是「正式安裝程式」的體感；而且未簽名的話，使用者第一次執行時 macOS 會跳出「無法驗證開發者」的警告，需要使用者自己去 **系統設定 → 隱私權與安全性** 裡允許執行。

### 方式 B：包成正式的 .pkg（比較推薦）

```bash
cd macos/
chmod +x build-pkg.sh hermes-onboarding-macos.sh
./build-pkg.sh
```

會產出一個 `HermesOnboarding-1.0.0.pkg`，使用者雙擊它,跟裝一般 Mac 軟體的體感一樣。

### 簽名 + 公證（強烈建議，否則 Gatekeeper 可能直接擋掉）

需要一個 [Apple Developer](https://developer.apple.com/) 帳號（年費，個人或公司皆可申請）跟對應的 **Developer ID Installer** 憑證。`build-pkg.sh` 執行完會印出完整指令，大致是：

```bash
productsign --sign "Developer ID Installer: 你的公司 (TEAMID)" \
  HermesOnboarding-1.0.0.pkg HermesOnboarding-1.0.0-signed.pkg

xcrun notarytool submit HermesOnboarding-1.0.0-signed.pkg \
  --keychain-profile "你的notary設定" --wait

xcrun stapler staple HermesOnboarding-1.0.0-signed.pkg
```

---

## 幾個重要的現實提醒

- **第一次安裝一定要有網路**——不管 Windows 還是 Mac,腳本背後都要連網下載 Hermes 的執行環境(Python/Node 等),沒有網路會直接失敗。建議在安裝包文案上提前告知使用者。
- **路徑是我依官方文件推測的常見安裝位置,正式發布前請務必先在乾淨的機器上實測一次**——例如全新帳號的 Windows/Mac,確認 `hermes` 執行檔真的出現在腳本裡寫的路徑,沒有的話照腳本印出的錯誤訊息調整路徑。
- **Profile Distribution repo 的存取權限要先確認好**——如果是公開 repo,使用者電腦不需要額外設定;如果是私有 repo,使用者的 git 需要先有對應的存取憑證(SSH key 或 git credential),不然 `hermes profile install` 那一步會失敗。
- **Hermes 本身仍在快速迭代**——這些路徑、安裝行為都是依目前(2026 年中)的官方文件跟原始碼回報整理出來的,如果 Hermes 之後改了安裝路徑或安裝邏輯,這些腳本可能要跟著微調。建議先用一小群測試使用者跑過一輪,確認順暢後再大量發布。
