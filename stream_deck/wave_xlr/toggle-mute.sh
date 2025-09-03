#!/usr/bin/env bash
set -euo pipefail

echo "=== Wave XLR Sync Mute Script (debug mode) ==="

# --- hardware: get card id ---
card_id="$(grep -m1 'Elgato Wave XLR' /proc/asound/cards | awk '{print $1}')"
echo "Detected card_id: '${card_id}'"
if [[ -z "$card_id" ]]; then
  echo "❌ Wave XLR not found in /proc/asound/cards"
  exit 1
fi

# --- software: pick the Elgato *input* source (not a monitor) ---
SOURCE="$(
  pactl list short sources \
    | awk '/Elgato/ && /input/ && !/monitor/ {print $2; exit}'
)"
echo "Detected mic SOURCE: '${SOURCE}'"
if [[ -z "$SOURCE" ]]; then
  echo "❌ Could not find Elgato *input* source. Available sources:"
  pactl list short sources | sed 's/^/  /'
  exit 1
fi

# --- read current hardware mute state ---
HW_STATE="$(amixer -c "$card_id" cget name='Mic Capture Switch' | awk -F= '/: values=/ {print $2; exit}')"
echo "Current hardware mute state: '${HW_STATE}'"

# --- toggle hardware first, then mirror to software ---
if [[ "$HW_STATE" == "on" ]]; then
  echo "Hardware currently UNMUTED → muting..."
  amixer -c "$card_id" cset name='Mic Capture Switch' off
  echo "Setting software mute ON for '${SOURCE}'"
  pactl set-source-mute "$SOURCE" 1
  MSG="🔇 Mic Muted"
else
  echo "Hardware currently MUTED → unmuting..."
  amixer -c "$card_id" cset name='Mic Capture Switch' on
  echo "Setting software mute OFF for '${SOURCE}'"
  pactl set-source-mute "$SOURCE" 0
  MSG="🎙️ Mic Unmuted"
fi

echo "Final status: ${MSG}"
command -v notify-send >/dev/null && notify-send "$MSG" || true
