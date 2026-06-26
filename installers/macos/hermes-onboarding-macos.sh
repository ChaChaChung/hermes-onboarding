#!/bin/bash
# ============================================================
# Hermes Agent 一鍵安裝腳本 (macOS)
# ============================================================
# 跟 Windows 版做一樣的兩件事：
#   1. 跑官方安裝腳本，裝好 Hermes Agent 本體
#      （Python 3.11+、Node.js、git、ripgrep、ffmpeg、hermes CLI）
#   2. 套用你預先準備好的 Profile Distribution（內建你的 proxy 設定）
#
# 使用前請先修改下面「請依需求修改」區塊。
#
# 兩種發布方式（詳見同目錄 README.md）：
#   A. 最簡單：把這個檔案改名成 "Install Hermes.command"，
#      chmod +x 之後直接給使用者，雙擊執行（會開一個 Terminal 視窗）。
#   B. 比較正式：用 build-pkg.sh 把這個腳本包成 .pkg 安裝包。
# ============================================================

set -euo pipefail

# ───────────────────────────────────────────────
PROFILE_REPO="github.com/ChaChaChung/hermes-myagent-profile"
PROFILE_ALIAS="myagent"                                # 安裝後的指令別名
# ───────────────────────────────────────────────

echo ""
echo "==> 安裝 Hermes Agent 核心..."
if ! curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash; then
    echo "官方安裝腳本執行失敗，請確認網路連線後再試一次。" >&2
    exit 1
fi

# ------------------------------------------------------------------
# 找出 hermes 執行檔。
# 安裝腳本通常會把 PATH 設定寫進 ~/.zshrc 或 ~/.bashrc，
# 但目前這個 shell session 可能還沒套用，所以這裡明確嘗試常見路徑。
#
# 注意：下面列出的路徑是依官方文件推測的常見安裝位置，
# 正式量產發布前，請務必在一台乾淨的 Mac 上實際跑一次，
# 確認路徑跟你環境裡的實際情況一致，必要時自行調整。
# ------------------------------------------------------------------
echo ""
echo "==> 尋找 hermes 執行檔..."

HERMES_BIN=""
for candidate in \
    "$HOME/.hermes/bin/hermes" \
    "$HOME/.local/bin/hermes"
do
    if [ -x "$candidate" ]; then
        HERMES_BIN="$candidate"
        break
    fi
done

if [ -z "$HERMES_BIN" ]; then
    HERMES_BIN="$(command -v hermes 2>/dev/null || true)"
fi

if [ -z "$HERMES_BIN" ]; then
    echo "找不到 hermes 執行檔。請開一個新的終端機視窗後手動執行：" >&2
    echo "  hermes profile install $PROFILE_REPO --alias -y" >&2
    exit 1
fi

echo "找到 hermes：$HERMES_BIN"

echo ""
echo "==> 安裝你的專屬設定（Profile Distribution: $PROFILE_REPO）..."
# --force：若同名 profile 已存在就覆蓋「設定檔」，但保留使用者自己的 .env / 金鑰 /
# 對話紀錄。這讓安裝程式可以安全地重複執行（重裝、更新都不會失敗）。
if ! "$HERMES_BIN" profile install "$PROFILE_REPO" --name "$PROFILE_ALIAS" --alias --force -y; then
    echo "安裝 Profile Distribution 失敗。請確認 $PROFILE_REPO 這個 git repo 在使用者電腦上能存取到。" >&2
    exit 1
fi

# ------------------------------------------------------------------
# 金鑰引導：這份 distribution 需要使用者自己的 AITOKENKING_API_KEY。
# 安裝完 .env 是空的（只有 .env.EXAMPLE 範本），若不填金鑰，
# Hermes 一對話就會報金鑰錯誤。這裡幫使用者把 .env 準備好、打開、並印出說明。
# ------------------------------------------------------------------
PROFILE_DIR="${HERMES_HOME:-$HOME/.hermes}/profiles/$PROFILE_ALIAS"
ENV_FILE="$PROFILE_DIR/.env"
ENV_EXAMPLE="$PROFILE_DIR/.env.EXAMPLE"

# 若還沒有 .env，就用範本複製一份出來給使用者填
if [ ! -f "$ENV_FILE" ] && [ -f "$ENV_EXAMPLE" ]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
fi

# 偵測金鑰是否已填（環境變數已設、或 .env 裡 AITOKENKING_API_KEY= 後面有值）
KEY_SET=0
if [ -n "${AITOKENKING_API_KEY:-}" ]; then
    KEY_SET=1
elif [ -f "$ENV_FILE" ] && grep -Eq '^[[:space:]]*AITOKENKING_API_KEY=[^[:space:]]+' "$ENV_FILE"; then
    KEY_SET=1
fi

if [ "$KEY_SET" -eq 0 ]; then
    # 自動用預設文字編輯器打開 .env，讓使用者直接貼金鑰
    [ -f "$ENV_FILE" ] && open -t "$ENV_FILE" 2>/dev/null || true
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  最後一步：填入你的 API 金鑰才能使用"
    echo ""
    echo "   1. 已為你打開設定檔（若沒自動打開請手動編輯）："
    echo "      $ENV_FILE"
    echo "   2. 找到這一行，把金鑰貼在 = 後面："
    echo "      AITOKENKING_API_KEY="
    echo "   3. 存檔後，重新開啟 Hermes Desktop 即可使用。"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# Hermes Desktop 需要 node/npm。官方安裝會把 node bootstrap 到 ~/.hermes/node/bin，
# 但這個非互動 shell 的 PATH 很精簡，可能不含它（也可能不含 Homebrew / ~/.local/bin），
# 導致 desktop 報「npm not found」而開不起來。這裡明確把常見的 node 路徑補進 PATH。
export PATH="${HERMES_HOME:-$HOME/.hermes}/node/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

echo ""
echo "==> 啟動 Hermes Desktop..."
# 重點：如果這個腳本是被 .pkg 的 postinstall 呼叫的，
# Installer 會一直等到本腳本的 stdout/stderr pipe 關閉才算「安裝完成」。
# hermes desktop 是常駐 GUI 程式，若直接用 "&" 背景執行，它會繼承同一個
# pipe 並一直握著不放 → Installer 永遠卡在「正在執行套件工序指令」。
# 因此這裡用 nohup + 重導向 + </dev/null + disown 把它徹底跟 pipe 切開。
nohup "$HERMES_BIN" desktop -p "$PROFILE_ALIAS" </dev/null >/tmp/hermes-desktop.log 2>&1 &
disown 2>/dev/null || true

echo ""
echo "完成！可以關閉這個視窗了。"
