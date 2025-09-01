#!/bin/bash

SOURCE="alsa_input.usb-Elgato_Systems_Elgato_Wave_XLR_DS41K3A02721-00.pro-input-0"

# Check current mute state
IS_MUTED=$(pactl get-source-mute "$SOURCE" | awk '{print $2}')

# Toggle mute state and show toast
if [[ "$IS_MUTED" == "yes" ]]; then
  pactl set-source-mute "$SOURCE" 0
  MSG="🎙️ Mic Unmuted"
else
  pactl set-source-mute "$SOURCE" 1
  MSG="🔇 Mic Muted"
fi

# Show toast or echo
command -v notify-send >/dev/null && notify-send "$MSG" || echo "$MSG"
