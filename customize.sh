#!/system/bin/sh
# BuildChain — KernelSU installation script

SKIPUNZIP=0

ui_print "================================================"
ui_print " BuildChain v1.0.0"
ui_print " On-device Android build toolchain"
ui_print "================================================"
ui_print ""

DEVICE=$(getprop ro.product.model)
ARCH=$(uname -m)
API=$(getprop ro.build.version.sdk)

ui_print "- Device: $DEVICE ($ARCH)"
ui_print "- Android API: $API"
ui_print ""

# Verify arch
case "$ARCH" in
    aarch64|arm64)
        ui_print "- Architecture: arm64 (supported)"
        ;;
    *)
        ui_print "! WARNING: Untested architecture: $ARCH"
        ui_print "! Build tools are compiled for arm64"
        ;;
esac

ui_print ""
ui_print "- Setting up config directory..."
CONFIG_DIR="/data/adb/buildchain"
mkdir -p "$CONFIG_DIR"
echo "$MODPATH" > "$CONFIG_DIR/moddir"

ui_print "- Setting permissions..."
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm_recursive $MODPATH/tools 0 2000 0755 0755
set_perm_recursive $MODPATH/scripts 0 2000 0755 0755
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/post-fs-data.sh 0 0 0755
set_perm $MODPATH/uninstall.sh 0 0 0755

# Verify tools work
ui_print ""
ui_print "- Testing build tools..."
for tool in aapt2 aidl zipalign; do
    if [ -f "$MODPATH/tools/build-tools/$tool" ]; then
        ui_print "  [OK] $tool"
    else
        ui_print "  [!!] $tool missing"
    fi
done

if [ -f "$MODPATH/tools/busybox" ]; then
    APPLETS=$("$MODPATH/tools/busybox" --list 2>/dev/null | wc -l)
    ui_print "  [OK] busybox ($APPLETS applets)"
else
    ui_print "  [!!] busybox missing"
fi

# Check Termux
ui_print ""
if pm list packages 2>/dev/null | grep -q "com.termux"; then
    ui_print "- Termux: installed"
    ui_print "- After reboot, open Termux and run:"
    ui_print "    buildchain setup"
else
    ui_print "! Termux not installed"
    ui_print "! Install Termux from F-Droid, then run: buildchain setup"
fi

ui_print ""
ui_print "- Installation complete!"
ui_print "- Reboot to activate"
ui_print "- CLI: buildchain status"
ui_print "- WebUI: http://localhost:8089"
ui_print ""
