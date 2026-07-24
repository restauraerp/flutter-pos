#!/usr/bin/env bash
#
# tab.sh — boot the tablet emulator and run the Flutter POS app on it.
#
#   * Launches the AVD with `-gpu host` (required on this machine, otherwise the
#     framebuffer stays black and frames take ~36s).
#   * Runs `flutter run` in the foreground, so you get hot reload (press `r`),
#     hot restart (`R`), quit (`q`) and live app logs in the terminal.
#   * On Ctrl+C the Flutter app quits gracefully first, then — if this script
#     started the emulator — the emulator is shut down cleanly (`adb emu kill`).
#     An emulator that was already running is left untouched.
#
# Override any path/name via env vars, e.g. `AVD=Foo ./tab.sh`.

set -euo pipefail

# ---- Configuration -----------------------------------------------------------
AVD="${AVD:-Pixel_Tablet_API_35}"
LABEL="${LABEL:-tab}"
GPU_MODE="${GPU_MODE:-host}"
FLUTTER="${FLUTTER:-$HOME/flutter/bin/flutter}"
EMULATOR="${EMULATOR:-$HOME/Android/Sdk/emulator/emulator}"
ADB="${ADB:-$HOME/Android/Sdk/platform-tools/adb}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

EMU_STARTED=0
SERIAL=""

log() { printf '\033[1;35m[%s]\033[0m %s\n' "$LABEL" "$*"; }

# ---- Graceful shutdown -------------------------------------------------------
cleanup() {
    trap - INT TERM EXIT   # avoid re-entry; a second Ctrl+C is then immediate
    if [ "$EMU_STARTED" = "1" ] && [ -n "$SERIAL" ]; then
        log "Shutting down emulator ($SERIAL)…"
        "$ADB" -s "$SERIAL" emu kill >/dev/null 2>&1 || true
    fi
    log "Done."
}
trap cleanup EXIT
# Bash defers a signal trap until the current foreground command returns, so
# `flutter run` receives the Ctrl+C first (and quits cleanly); only then does
# this fire, run the EXIT trap, and tear the emulator down.
trap 'echo; log "Interrupted."; exit 130' INT TERM

# ---- Find the emulator serial for our AVD (if it is already running) ---------
find_serial_for_avd() {
    local s name
    for s in $("$ADB" devices | awk '/emulator-/{print $1}'); do
        name="$("$ADB" -s "$s" emu avd name 2>/dev/null | head -1 | tr -d '\r')"
        [ "$name" = "$AVD" ] && { echo "$s"; return 0; }
    done
    return 1
}

# ---- Boot (or reuse) the emulator --------------------------------------------
"$ADB" start-server >/dev/null 2>&1 || true

if SERIAL="$(find_serial_for_avd)"; then
    log "Emulator '$AVD' already running as $SERIAL — reusing it."
else
    log "Booting emulator '$AVD' (gpu=$GPU_MODE)…"
    "$EMULATOR" -avd "$AVD" -gpu "$GPU_MODE" >/dev/null 2>&1 &
    EMU_STARTED=1
    # Poll by AVD name so this works even when several emulators boot at the
    # same time (e.g. running phone.sh and tab.sh together). Every adb call
    # below is scoped to our own serial, never the ambiguous default device.
    log "Waiting for device to register…"
    until SERIAL="$(find_serial_for_avd)"; do sleep 1; done
fi

log "Waiting for Android to finish booting…"
"$ADB" -s "$SERIAL" wait-for-device
until [ "$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
    sleep 1
done
log "Emulator ready: $SERIAL"

# ---- Run the app (foreground: hot reload + live logs) ------------------------
cd "$PROJECT_DIR"
log "Launching Flutter app — r=hot reload, R=hot restart, q=quit."
"$FLUTTER" run -d "$SERIAL"
