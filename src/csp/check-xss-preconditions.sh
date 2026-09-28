#!/usr/bin/env bash
# Does a host meet the preconditions for an injected script tag to EXECUTE?
#
# Two conditions have to hold at once:
#   1. The application ships a jQuery whose .html() routes script tags through
#      append -> domManip -> globalEval -> eval, so injected markup runs.
#   2. The host serves no Content-Security-Policy, so nothing blocks that eval,
#      inline handlers, or loading an external script.
#
# Either one alone is not a finding. Both together mean any stored or reflected
# injection on that host executes.
#
# Usage: ./check-xss-preconditions.sh <host> <app-js-url> [cookie]

if [ -z "$2" ]; then
    echo "Usage: $0 <host> <app-js-url> [cookie]"
    exit 1
fi

HOST="$1"
JSURL="$2"
COOKIE="${3:-}"
[[ "$HOST" =~ ^https?:// ]] || HOST="https://$HOST"

H=$(mktemp); P=$(mktemp); J=$(mktemp)
trap 'rm -f "$H" "$P" "$J"' EXIT

echo "HOST: $HOST"

# --- condition 2: no CSP on the host -------------------------------------
curl -sS -D "$H" -o "$P" ${COOKIE:+-H "Cookie: $COOKIE"} "$HOST" || { echo "request failed"; exit 2; }
echo "  page status: $(head -1 "$H" | tr -d '\r')"
CSP=$(grep -Ei '^content-security-policy(-report-only)?:' "$H")
CSPMETA=$(tr -d '\n' < "$P" | grep -Eio '<meta[^>]*http-equiv=["'"'"' ]*content-security-policy[^>]*>')
if [ -n "$CSP$CSPMETA" ]; then
    NOCSP=0; echo "  CSP: PRESENT"
else
    NOCSP=1; echo "  CSP: NONE - nothing blocks script execution"
fi

# --- condition 1: script-executing .html() path in the app bundle --------
curl -sS -o "$J" ${COOKIE:+-H "Cookie: $COOKIE"} "$JSURL" || { echo "bundle fetch failed"; exit 2; }
VER=$(grep -oiE 'jQuery (JavaScript Library )?v?[0-9]+\.[0-9]+\.[0-9]+' "$J" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u | head -1)
GE=$(grep -oF globalEval "$J" | wc -l)
echo "  bundle: $JSURL"
echo "  bundle bytes: $(wc -c < "$J")"
echo "  jQuery version: ${VER:-NOT FOUND}   globalEval occurrences: $GE"
if [ "$GE" -gt 0 ]; then
    EVALPATH=1; echo "  .html() script execution path: PRESENT"
else
    EVALPATH=0; echo "  .html() script execution path: absent"
fi

echo
if [ "$NOCSP" -eq 1 ] && [ "$EVALPATH" -eq 1 ]; then
    echo "RESULT: $HOST is EXPOSED - injected script tags will execute and no CSP blocks them"
    exit 0
fi
echo "RESULT: $HOST does not meet both preconditions"
exit 1
