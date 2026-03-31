#!/system/bin/sh
# BuildChain — early boot: install busybox applets system-wide, set up paths
MODDIR=${0%/*}
CONFIG_DIR="/data/adb/buildchain"

mkdir -p "$CONFIG_DIR"
echo "$MODDIR" > "$CONFIG_DIR/moddir"

# Install busybox applets to /system/xbin via module overlay
XBIN="$MODDIR/system/xbin"
mkdir -p "$XBIN"

if [ -f "$MODDIR/tools/busybox" ]; then
  cp "$MODDIR/tools/busybox" "$XBIN/busybox"
  chmod 0755 "$XBIN/busybox"

  # Create symlinks for all busybox applets
  "$XBIN/busybox" --list 2>/dev/null | while read applet; do
    [ "$applet" = "busybox" ] && continue
    # Don't override core Android binaries
    case "$applet" in
      sh|ls|cat|cp|mv|rm|mkdir|chmod|chown|mount|umount|reboot|ps|kill|ln|df|du) continue ;;
    esac
    ln -sf busybox "$XBIN/$applet" 2>/dev/null
  done
fi
