#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
"$ROOT/build.sh"

APP_NAME="RMOS Spotlight.app"
SRC="$ROOT/build/$APP_NAME"
DEST="/Applications/$APP_NAME"

echo "Yükleniyor: $DEST..."
# Kill running instance if exists
pkill -f "RMOSSpotlight" 2>/dev/null || true
sleep 0.5

rm -rf "$DEST"
cp -R "$SRC" "$DEST"
xattr -cr "$DEST"

echo "Başlatılıyor: $DEST"
open "$DEST"

echo ""
echo "=== RM-OS Spotlight Hazır! ==="
echo "• Menü çubuğundaki büyüteç ikonuna tıkla, veya"
echo "• Herhangi bir ekranda 'Option + Space' (⌥ + Boşluk) tuşlarına bas!"
echo "• Arama çubuğu 'rmos-remote search ' hazır yazılı açılır."
