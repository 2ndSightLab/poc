#!/usr/bin/env bash
# Does an error response disclose component names and versions?
#
# Many frameworks render a debug page on an unhandled exception. A malformed
# request body is often enough to trigger one before any authentication runs,
# because body parsing happens in middleware ahead of the auth filter.
#
# Usage: ./check-version-disclosure.sh <url> [content-type] [body] [cookie]
#        ./check-version-disclosure.sh https://host.example.com/api/thing
#        ./check-version-disclosure.sh https://host.example.com/ application/json 'invalid json'
#
# Defaults to POST application/json with a deliberately malformed body.
# No cookie is sent unless one is given, so a hit proves the disclosure is
# reachable unauthenticated.

if [ -z "$1" ]; then
    echo "Usage: $0 <url> [content-type] [body] [cookie]"
    exit 1
fi

URL="$1"
CT="${2:-application/json}"
BODY="${3:-invalid json}"
COOKIE="${4:-}"

B=$(mktemp); H=$(mktemp)
trap 'rm -f "$B" "$H"' EXIT

curl -sS -m 30 -D "$H" -o "$B" -X POST \
     -H "Content-Type: $CT" -d "$BODY" \
     ${COOKIE:+-H "Cookie: $COOKIE"} "$URL" || { echo "request failed"; exit 2; }

echo "URL:    $URL"
echo "Status: $(head -1 "$H" | tr -d '\r')"
echo "Bytes:  $(wc -c < "$B")"
echo "Title:  $(grep -oiE '<title>[^<]*</title>' "$B" | head -1)"

echo "--- component versions disclosed ---"
# Two to four version components, so 1.4.7 and 3.2.22.5 both match.
VERS=$(grep -oiE '[a-z][a-z0-9_-]+ \(?[0-9]+(\.[0-9]+){1,3}\)?' "$B" | sort -u)
echo "${VERS:-none}"

echo "--- paths disclosed ---"
grep -oiE '(Rails\.root|DOCUMENT_ROOT)[^<]{0,60}|/(opt|app|usr|home|var)/[a-z0-9_./-]{4,60}' "$B" | sort -u | head -15

if [ -n "$VERS" ]; then
    echo "RESULT: versions disclosed"
    exit 0
fi
echo "RESULT: no versions disclosed"
exit 1
