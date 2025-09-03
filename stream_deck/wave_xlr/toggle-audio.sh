#!/bin/bash
# Toggle Elgato <-> Family, but robust against fast repeated presses.

LOCK="/tmp/wpctl-toggle.lock"
exec 9>"$LOCK"
flock -n 9 || exit 0   # if another instance is running, bail silently

NAME_ELGATO="alsa_output.usb-Elgato_Systems_Elgato_Wave_XLR_DS41K3A02721-00.pro-output-0"
DESC_FAMILY="Family 17h/19h/1ah HD Audio Controller Analog Stereo"

extract_id() { sed -nE 's/^[^0-9]*([0-9]+)\..*/\1/p' | head -n1; }

ID_ELGATO=$(wpctl status | grep -F "$NAME_ELGATO" | extract_id)

ID_FAMILY=$(wpctl status \
  | sed -n '/Sinks:/,/Sources:/p' \
  | grep -F "$DESC_FAMILY" | extract_id)

if [[ -z "$ID_FAMILY" ]]; then
  ID_FAMILY=$(wpctl status | grep -F "Family 17h" | grep -F "[Audio/Sink]" | extract_id)
fi

if [[ -z "$ID_ELGATO" || -z "$ID_FAMILY" ]]; then
  echo "❌ Could not resolve IDs. ELGATO='$ID_ELGATO' FAMILY='$ID_FAMILY'"; exit 1
fi

DEF_NODE=$(wpctl status | awk '/Default Configured Devices:/ {f=1; next} f && /Audio\/Sink/ {print $NF; exit}')

if [[ "$DEF_NODE" == "$NAME_ELGATO" ]]; then
  TARGET="$ID_FAMILY"; TOAST="🔊 Output → Family 17h"
else
  TARGET="$ID_ELGATO"; TOAST="🔊 Output → Elgato Wave XLR"
fi

# 1) Flip default
wpctl set-default "$TARGET"

# small settle for WirePlumber routing metadata propagation
sleep 0.15

# 2) Move all active output streams; retry a few times to catch stragglers
move_streams_once() {
  wpctl status \
  | awk '/^ └─ Streams:/,/^$/{ if ($1 ~ /^[0-9]+\./){gsub(/\./,"",$1); print $1} }' \
  | while read -r sid; do
      # Only move output streams
      if wpctl inspect "$sid" 2>/dev/null | grep -q 'media.class = "Stream/Output"'; then
        # Send to whatever is CURRENT default (resilient if default changed again)
        wpctl move-node "$sid" @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1
      fi
    done
}

# Try a few quick passes to avoid races on fast presses
for _ in 1 2 3; do
  move_streams_once
  sleep 0.15
done

#command -v notify-send >/dev/null && notify-send "$TOAST" || echo "$TOAST"
echo "$TOAST"
