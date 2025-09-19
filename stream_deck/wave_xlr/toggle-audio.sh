#!/bin/bash
# Rotate default PipeWire sink across all output devices.
# Strategy:
# 1) Prefer pw-dump+jq (stable JSON across versions)
# 2) Fallback to parsing `wpctl status`
# 3) Keep lock + multi-pass stream move; allow exclude regex.

set -euo pipefail
export LC_ALL=C

LOCK="/tmp/wpctl-toggle.lock"
exec 9>"$LOCK"
flock -n 9 || exit 0

EXCLUDE_SINKS_REGEX="${EXCLUDE_SINKS_REGEX:-}"  # e.g. '(Dummy|Monitor|Easy Effects)'

has() { command -v "$1" >/dev/null 2>&1; }

# ---------- JSON path (preferred) ----------
extract_sinks_json() {
  # Emits: "<id>\t<name>"
  # name preference: node.description > node.nick > node.name
  pw-dump \
  | jq -r '
      .[]
      | select(.type=="PipeWire:Interface:Node")
      | select(.info.props["media.class"]=="Audio/Sink")
      | [
          (.id|tostring),
          (.info.props["node.description"]
           // .info.props["node.nick"]
           // .info.props["node.name"])
        ]
      | @tsv
    ' 2>/dev/null || true
}

get_default_sink_id_json() {
  # Try wpctl inspect first; it’s fast and stable
  wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null \
    | sed -nE 's/^[[:space:]]*id = ([0-9]+).*$/\1/p' \
    | head -n1
}

# ---------- Fallback (wpctl status) ----------
extract_sinks_status() {
  wpctl status \
  | sed -n '/Sinks:/,/Sources:/p' \
  | sed '1d;$d' \
  | sed 's/^[[:space:]]*[│└├┌└─]*[[:space:]]*//; s/^[[:space:]]*\*//;' \
  | awk '$1 ~ /^[0-9]+\.$/ {
           id=$1; sub(/\./,"",id);
           $1=""; sub(/^[[:space:]]*/,"");
           sub(/[[:space:]]*\[vol:.*$/,"");
           gsub(/[[:space:]]+$/,"");
           if(length($0)>0) print id "\t" $0
         }'
}

get_default_sink_id_status() {
  wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null \
    | sed -nE 's/^[[:space:]]*id = ([0-9]+).*$/\1/p' \
    | head -n1 \
  || true
  # If empty, parse the starred line
  if [[ -z "${id:-}" ]]; then
    id="$(wpctl status \
        | sed -n '/Sinks:/,/Sources:/p' \
        | grep -E '^\s*[│└├┌└─]*\s*\*' \
        | sed -E 's/^[[:space:]]*[│└├┌└─]*[[:space:]]*\*//; s/^[[:space:]]*([0-9]+)\..*$/\1/' \
        | head -n1 || true)"
  fi
  echo "${id:-}"
}

move_streams_once() {
  # Move active output streams to current default
  wpctl status \
  | awk '/^ └─ Streams:/,/^$/{ if ($1 ~ /^[0-9]+\./){gsub(/\./,"",$1); print $1} }' \
  | while read -r sid; do
      if wpctl inspect "$sid" 2>/dev/null | grep -q 'media.class = "Stream/Output"'; then
        wpctl move-node "$sid" @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1 || true
      fi
    done
}

# ---------- collect sinks ----------
SINK_LINES=()
if has pw-dump && has jq; then
  while IFS= read -r line; do SINK_LINES+=("$line"); done < <(extract_sinks_json)
fi
# Fallback if JSON path produced nothing
if ((${#SINK_LINES[@]}==0)); then
  while IFS= read -r line; do SINK_LINES+=("$line"); done < <(extract_sinks_status)
fi

# Optional exclude by regex
if [[ -n "$EXCLUDE_SINKS_REGEX" && ${#SINK_LINES[@]} -gt 0 ]]; then
  mapfile -t SINK_LINES < <(printf '%s\n' "${SINK_LINES[@]}" | grep -Pv -- "$EXCLUDE_SINKS_REGEX" || true)
fi

((${#SINK_LINES[@]})) || { echo "❌ No sinks found."; exit 1; }

IDS=(); NAMES=()
for ln in "${SINK_LINES[@]}"; do
  IDS+=("${ln%%$'\t'*}")
  NAMES+=("${ln#*$'\t'}")
done

((${#IDS[@]}>=2)) || { echo "❌ Only one sink available; nothing to toggle."; exit 1; }

# figure current default
CURR_ID="$(get_default_sink_id_json || true)"
[[ -n "$CURR_ID" ]] || CURR_ID="$(get_default_sink_id_status || true)"
idx_curr=0
for i in "${!IDS[@]}"; do [[ "${IDS[$i]}" == "$CURR_ID" ]] && { idx_curr=$i; break; }; done

# rotate
next_idx=$(( (idx_curr + 1) % ${#IDS[@]} ))
TARGET_ID="${IDS[$next_idx]}"; TARGET_NAME="${NAMES[$next_idx]}"

wpctl set-default "$TARGET_ID"
sleep 0.15
for _ in 1 2 3; do move_streams_once; sleep 0.15; done

echo "🔊 Output → ${TARGET_NAME}"
