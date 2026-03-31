#!/system/bin/sh
CONFIG_DIR="/data/adb/buildchain"
PID_FILE="$CONFIG_DIR/webui.pid"
TERMUX_BIN="/data/data/com.termux/files/usr/bin"
TERMUX_ETC="/data/data/com.termux/files/usr/etc"

[ -f "$PID_FILE" ] && kill $(cat "$PID_FILE") 2>/dev/null

# Remove Termux symlinks
for tool in aapt aapt2 aidl dexdump zipalign split-select buildchain buildchain-setup bc-build bc-sign; do
  rm -f "$TERMUX_BIN/$tool" 2>/dev/null
done
rm -f "$TERMUX_ETC/profile.d/buildchain.sh" 2>/dev/null

rm -rf "$CONFIG_DIR"
