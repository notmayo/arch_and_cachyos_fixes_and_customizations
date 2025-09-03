#!/usr/bin/env bash
set -euo pipefail

# find the card id number for "Elgato Wave XLR"
card_id="$(grep -m1 -B0 'Elgato Wave XLR' /proc/asound/cards | awk '{print $1}')"

if [[ -z "$card_id" ]]; then
  echo "❌ Wave XLR not found" >&2
  exit 1
fi

# toggle the hardware mute
amixer -c "$card_id" cset name='Mic Capture Switch' toggle
