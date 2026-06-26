#!/bin/bash
# ============================================================
# 把 hermes-onboarding-macos.sh 包成一個正式的 .pkg 安裝包
# ============================================================
# 用法：
#   chmod +x build-pkg.sh
#   ./build-pkg.sh
#
# 需求：macOS 內建的 pkgbuild 指令即可
#   （裝 Xcode Command Line Tools 就有，不需要完整 Xcode：
#    xcode-select --install）
#
# 這個 pkg 不安裝任何檔案，純粹是「裝的時候跑一段腳本」
# （--nopayload），腳本內容就是 hermes-onboarding-macos.sh。
# ============================================================

set -euo pipefail

# ──────────────── 請依需求修改 ────────────────
APP_NAME="HermesOnboarding"
VERSION="1.0.0"
IDENTIFIER="com.yourcompany.hermesonboarding"   # 換成你自己的反向網域命名
# ───────────────────────────────────────────────

OUTPUT_PKG="${APP_NAME}-${VERSION}.pkg"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(mktemp -d)"
SCRIPTS_DIR="$WORK_DIR/scripts"
mkdir -p "$SCRIPTS_DIR"

# pkgbuild 的 postinstall 腳本預設會以 root 權限執行，
# 但 Hermes 是裝在使用者自己的 home 目錄底下（per-user 安裝），
# 不該用 root 身分去裝，所以這裡切回「目前實際登入的使用者」身分執行。
cat > "$SCRIPTS_DIR/postinstall" <<'POSTINSTALL_EOF'
#!/bin/bash
set -e
REAL_USER=$(stat -f "%Su" /dev/console)
REAL_UID=$(id -u "$REAL_USER")
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
launchctl asuser "$REAL_UID" sudo -u "$REAL_USER" bash "$SCRIPT_DIR/hermes-onboarding-macos.sh"
POSTINSTALL_EOF
chmod +x "$SCRIPTS_DIR/postinstall"

cp "$SCRIPT_DIR/hermes-onboarding-macos.sh" "$SCRIPTS_DIR/hermes-onboarding-macos.sh"
chmod +x "$SCRIPTS_DIR/hermes-onboarding-macos.sh"

pkgbuild \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --scripts "$SCRIPTS_DIR" \
    --nopayload \
    "$SCRIPT_DIR/$OUTPUT_PKG"

rm -rf "$WORK_DIR"

echo ""
echo "打包完成：$SCRIPT_DIR/$OUTPUT_PKG"
echo ""
echo "下一步（強烈建議，否則 Gatekeeper 會擋掉或跳警告）："
echo "  1. 簽名（需要 Apple Developer ID Installer 憑證）："
echo "     productsign --sign \"Developer ID Installer: 你的公司 (TEAMID)\" \\"
echo "       $OUTPUT_PKG ${OUTPUT_PKG%.pkg}-signed.pkg"
echo ""
echo "  2. 送公證："
echo "     xcrun notarytool submit ${OUTPUT_PKG%.pkg}-signed.pkg \\"
echo "       --keychain-profile \"你預先設定好的 notary profile 名稱\" --wait"
echo ""
echo "  3. 蓋章（讓離線安裝時也能通過 Gatekeeper 檢查）："
echo "     xcrun stapler staple ${OUTPUT_PKG%.pkg}-signed.pkg"
