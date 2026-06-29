# Hermes Agent（暫定名稱）安裝包 repo

> 官網首頁（`index.html`）已搬到 `hermes-proxy` repo，改由 proxy 服務在根路徑 `/` 直接提供（檔案位於 `hermes-proxy/app/static/index.html`）。這個 repo 現在只負責安裝包的打包與發布。

這個 repo 包含兩個部分：

```
.
├── installers/
│   ├── README.md                       ← 安裝包詳細說明（簽名、打包步驟等）
│   ├── windows/
│   │   ├── hermes-setup.iss            ← Inno Setup 安裝包定義
│   │   └── run-onboarding.ps1          ← 實際安裝邏輯
│   └── macos/
│       ├── hermes-onboarding-macos.sh  ← 實際安裝邏輯
│       └── build-pkg.sh                ← 把上面那個腳本包成 .pkg
└── .github/workflows/build-installers.yml  ← 自動打包 + 發 Release
```

---

## 第一次 push 上 GitHub

```bash
cd hermes-agent-repo
git init
git add .
git commit -m "first commit: website + installers"
git branch -M main
git remote add origin git@github.com:你的帳號/你的repo名稱.git
git push -u origin main
```

（如果還沒在這台機器上設定過 GitHub 的 SSH key 或認證，先去 GitHub 設定一組，或改用 HTTPS + Personal Access Token。）

---

## 官網首頁

首頁已不再由這個 repo 的 GitHub Pages 提供，而是搬到 `hermes-proxy`，由 proxy 服務直接在根路徑 `/` 回傳 `app/static/index.html`。要改首頁內容請到那個 repo 編輯後重新部署 proxy。

---

## 自動打包安裝包（GitHub Actions）

`.github/workflows/build-installers.yml` 設定好之後：

- 每次你 push 一個版本 tag（例如 `git tag v1.0.0 && git push --tags`），會自動：
  1. 在 Windows runner 上用 Inno Setup 編譯出 `.exe`
  2. 在 macOS runner 上跑 `build-pkg.sh` 編出 `.pkg`
  3. 把兩個檔案都附加到一個新的 GitHub Release 上
- 也可以不打 tag，直接去 repo 的 **Actions** 頁籤，選這個 workflow，按 **Run workflow** 手動觸發一次

編完之後，去 repo 的 **Releases** 頁面就能看到附件，網址大概像：

```
https://github.com/你的帳號/你的repo名稱/releases/download/v1.0.0/HermesAgent-Setup.exe
```

把這個網址貼到 `hermes-proxy/app/static/index.html` 裡那兩個下載按鈕的 `href`，就完成串接了。

### 這個 workflow 還沒處理的事

- **沒有簽名**：編出來的 `.exe`/`.pkg` 是未簽名的，使用者第一次執行還是會看到 SmartScreen / Gatekeeper 警告。要簽名的話，要把你的憑證存成 GitHub Actions 的 secrets，再修改 workflow 加上簽名步驟（`signtool` / `productsign` + `notarytool`）。
- **macOS runner 版本**、Inno Setup 透過 Chocolatey 安裝的版本，都可能隨 GitHub 自己更新而變動，第一次跑建議實際看一次 Actions 的執行 log，確認沒有報錯。

---

## 重要提醒（公開 repo）

GitHub Pages 免費方案只能用在**公開 repo**上，這代表 repo 裡所有檔案的內容都是公開可見的。目前這些檔案裡沒有放任何密鑰，只有 `base_url` 跟你的 Profile Distribution repo 路徑（這兩個本來就不算敏感資訊），可以放心公開。

但之後不管是誰要往這個 repo 加東西，**絕對不要 commit 任何 `.env`、API key、aitokenking 的密鑰、或程式碼簽名憑證（`.pfx`/`.p12`）進來**——`.gitignore` 已經先擋掉這些副檔名，但這只能防手滑，不能防故意，團隊裡的人都要知道這條規則。
