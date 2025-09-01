#!/bin/bash
# Toggle Elgato <-> Family using dynamic numeric IDs from `wpctl status`

NAME_ELGATO="alsa_output.usb-Elgato_Systems_Elgato_Wave_XLR_DS41K3A02721-00.pro-output-0"
DESC_FAMILY="Family 17h/19h/1ah HD Audio Controller Analog Stereo"

# helper: extract the FIRST leading "NN." id from a line, ignoring other numbers later
extract_id() { sed -nE 's/^[^0-9]*([0-9]+)\..*/\1/p' | head -n1; }

# Elgato ID: match exact node.name anywhere (shows under Filters)
ID_ELGATO=$(wpctl status \
  | grep -F "$NAME_ELGATO" \
  | extract_id)

# Family ID: match human description inside the Sinks block
ID_FAMILY=$(wpctl status \
  | sed -n '/Sinks:/,/Sources:/p' \
  | grep -F "$DESC_FAMILY" \
  | extract_id)

# Fallback for Family if not found in Sinks (rare)
if [[ -z "$ID_FAMILY" ]]; then
  ID_FAMILY=$(wpctl status | grep -F "Family 17h" | grep -F "[Audio/Sink]" | extract_id)
fi

if [[ -z "$ID_ELGATO" || -z "$ID_FAMILY" ]]; then
  echo "❌ Could not resolve IDs. ELGATO='$ID_ELGATO' FAMILY='$ID_FAMILY'"; exit 1
fi

# Current default node.name (string, not number)
DEF_NODE=$(wpctl status | awk '/Default Configured Devices:/ {f=1; next} f && /Audio\/Sink/ {print $NF; exit}')

# If default is Elgato node.name, switch to Family; else to Elgato
if [[ "$DEF_NODE" == "$NAME_ELGATO" ]]; then
  TARGET="$ID_FAMILY"; TOAST="🔊 Output → Family 17h"
else
  TARGET="$ID_ELGATO"; TOAST="🔊 Output → Elgato Wave XLR"
fi

# Switch and move active streams
wpctl set-default "$TARGET"

wpctl status \
| awk '/^ └─ Streams:/,/^$/{ if ($1 ~ /^[0-9]+\./){gsub(/\./,"",$1); print $1} }' \
| while read -r sid; do
    wpctl inspect "$sid" 2>/dev/null | grep -q 'media.class = "Stream/Output"' && wpctl move-node "$sid" "$TARGET" >/dev/null 2>&1
  done

command -v notify-send >/dev/null && notify-send "$TOAST" || echo "$TOAST"
