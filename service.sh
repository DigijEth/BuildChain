#!/system/bin/sh
# BuildChain — late service: link tools into framework, hook Termux, start WebUI
MODDIR=${0%/*}
CONFIG_DIR="/data/adb/buildchain"
LOG="$CONFIG_DIR/buildchain.log"
PID_FILE="$CONFIG_DIR/webui.pid"
TOOLS="$MODDIR/tools"
TERMUX_PREFIX="/data/data/com.termux/files/usr"
TERMUX_BIN="$TERMUX_PREFIX/bin"
TERMUX_LIB="$TERMUX_PREFIX/lib"
TERMUX_ETC="$TERMUX_PREFIX/etc"
TERMUX_HOME="/data/data/com.termux/files/home"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }

mkdir -p "$CONFIG_DIR"
log "BuildChain service starting"

# Wait for system to settle
sleep 8

#############################
# Detect installed components
#############################

detect_environment() {
  local env_file="$CONFIG_DIR/environment.json"

  local has_termux="false"
  local has_termux_api="false"
  local has_java="false"
  local java_version=""
  local has_python="false"
  local python_version=""
  local has_kotlin="false"
  local kotlin_version=""
  local has_gradle="false"
  local gradle_version=""
  local has_git="false"

  [ -d "$TERMUX_BIN" ] && has_termux="true"

  # Check Termux packages
  if [ "$has_termux" = "true" ]; then
    [ -f "$TERMUX_BIN/termux-api-start" ] || pm list packages 2>/dev/null | grep -q "com.termux.api" && has_termux_api="true"
    if [ -f "$TERMUX_BIN/java" ]; then
      has_java="true"
      java_version=$("$TERMUX_BIN/java" -version 2>&1 | head -1)
    fi
    if [ -f "$TERMUX_BIN/python" ] || [ -f "$TERMUX_BIN/python3" ]; then
      has_python="true"
      python_version=$("$TERMUX_BIN/python3" --version 2>/dev/null || "$TERMUX_BIN/python" --version 2>/dev/null)
    fi
    if [ -f "$TERMUX_BIN/kotlin" ] || [ -f "$TERMUX_BIN/kotlinc" ]; then
      has_kotlin="true"
      kotlin_version=$("$TERMUX_BIN/kotlinc" -version 2>&1 | head -1)
    fi
    if [ -f "$TERMUX_BIN/gradle" ]; then
      has_gradle="true"
      gradle_version=$("$TERMUX_BIN/gradle" --version 2>/dev/null | grep "Gradle " | head -1)
    fi
    [ -f "$TERMUX_BIN/git" ] && has_git="true"
  fi

  # Arch
  local arch=$(uname -m)
  local api=$(getprop ro.build.version.sdk)
  local device=$(getprop ro.product.model)

  cat > "$env_file" << ENVJSON
{
  "arch": "$arch",
  "api_level": "$api",
  "device": "$device",
  "termux": $has_termux,
  "termux_api": $has_termux_api,
  "java": $has_java,
  "java_version": "$java_version",
  "python": $has_python,
  "python_version": "$python_version",
  "kotlin": $has_kotlin,
  "kotlin_version": "$kotlin_version",
  "gradle": $has_gradle,
  "gradle_version": "$gradle_version",
  "git": $has_git,
  "build_tools_version": "35.0.2",
  "busybox": true
}
ENVJSON

  log "Environment detected: termux=$has_termux java=$has_java python=$has_python kotlin=$has_kotlin gradle=$has_gradle"
}

detect_environment

#############################
# Link build tools into system PATH (via /system/xbin overlay)
#############################

link_system_tools() {
  local xbin="$MODDIR/system/xbin"
  mkdir -p "$xbin"

  # Build tools — always available system-wide
  for tool in aapt aapt2 aidl dexdump zipalign split-select; do
    [ -f "$TOOLS/build-tools/$tool" ] && ln -sf "$TOOLS/build-tools/$tool" "$xbin/$tool" 2>/dev/null
  done

  # Platform tools that aren't already in /system/bin
  for tool in sqlite3 etc1tool hprof-conv e2fsdroid make_f2fs sload_f2fs mke2fs; do
    [ -f "$TOOLS/platform-tools/$tool" ] && ln -sf "$TOOLS/platform-tools/$tool" "$xbin/$tool" 2>/dev/null
  done

  # Our management scripts
  for script in "$MODDIR"/scripts/*; do
    [ -f "$script" ] && ln -sf "$script" "$xbin/$(basename $script)" 2>/dev/null
  done

  log "System tools linked to $xbin"
}

link_system_tools

#############################
# Hook into Termux
#############################

hook_termux() {
  if [ ! -d "$TERMUX_BIN" ]; then
    log "Termux not installed — skipping hooks"
    return
  fi

  # Symlink build tools into Termux bin (so they're on Termux's PATH too)
  for tool in aapt aapt2 aidl dexdump zipalign split-select; do
    [ -f "$TOOLS/build-tools/$tool" ] && ln -sf "$TOOLS/build-tools/$tool" "$TERMUX_BIN/$tool" 2>/dev/null
  done

  # Link our CLI scripts into Termux
  for script in "$MODDIR"/scripts/*; do
    [ -f "$script" ] && ln -sf "$script" "$TERMUX_BIN/$(basename $script)" 2>/dev/null
  done

  # Create Termux profile.d hook for environment
  mkdir -p "$TERMUX_ETC/profile.d"
  cat > "$TERMUX_ETC/profile.d/buildchain.sh" << 'PROFEOF'
# BuildChain — auto-sourced by Termux on shell start
[ -f /data/adb/buildchain/env.sh ] && . /data/adb/buildchain/env.sh
PROFEOF

  # Write the environment file
  cat > "$CONFIG_DIR/env.sh" << ENVEOF
# BuildChain environment
export BUILDCHAIN_HOME="$MODDIR"
export ANDROID_BUILD_TOOLS="$TOOLS/build-tools"
export ANDROID_PLATFORM_TOOLS="$TOOLS/platform-tools"
export ANDROID_HOME="$TERMUX_HOME/android-sdk"
export ANDROID_SDK_ROOT="\$ANDROID_HOME"
export PATH="\$ANDROID_BUILD_TOOLS:\$ANDROID_PLATFORM_TOOLS:\$PATH"

# Java — detect from Termux
for jdir in $TERMUX_PREFIX/lib/jvm/java-21-openjdk $TERMUX_PREFIX/lib/jvm/java-17-openjdk; do
  if [ -d "\$jdir" ]; then
    export JAVA_HOME="\$jdir"
    export PATH="\$JAVA_HOME/bin:\$PATH"
    break
  fi
done

# Gradle home
[ -d "$TERMUX_HOME/.gradle" ] && export GRADLE_USER_HOME="$TERMUX_HOME/.gradle"

# Kotlin
[ -d "$TERMUX_PREFIX/share/kotlin" ] && export KOTLIN_HOME="$TERMUX_PREFIX/share/kotlin"
ENVEOF

  log "Termux hooks installed"
}

hook_termux

#############################
# Start WebUI
#############################

if [ -f "$PID_FILE" ]; then
  kill $(cat "$PID_FILE") 2>/dev/null
  rm -f "$PID_FILE"
fi

log "Starting WebUI on port 8089"
nohup sh "$MODDIR/scripts/webui-server" >> "$LOG" 2>&1 &
echo $! > "$PID_FILE"

log "BuildChain service complete (WebUI PID: $(cat $PID_FILE))"
