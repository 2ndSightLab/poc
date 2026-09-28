#!/usr/bin/env bash
# Check whether a URL returns a Content-Security-Policy, as a header or a meta tag.
# A CSP can be delivered two ways, so both are checked and absence is conclusive.
# Redirects are NOT followed, so the result is for the URL given and not a login page.
#
# Usage: ./check-csp.sh <url-or-domain> [cookie]
#        ./check-csp.sh example.com
#        ./check-csp.sh example.com 'session=abc123'

if [ -z "$1" ]; then
    echo "Usage: $0 <url-or-domain> [cookie]"
    exit 1
fi

URL="$1"
COOKIE="${2:-}"
[[ "$URL" =~ ^https?:// ]] || URL="https://$URL"

H=$(mktemp)
B=$(mktemp)
trap 'rm -f "$H" "$B"' EXIT

curl -sS -D "$H" -o "$B" ${COOKIE:+-H "Cookie: $COOKIE"} "$URL" || {
    echo "request failed"
    exit 2
}

echo "URL:    $URL"
echo "Status: $(head -1 "$H" | tr -d '\r')"

HDR=$(grep -Ei '^content-security-policy(-report-only)?:' "$H")
META=$(tr -d '\n' < "$B" | grep -Eio '<meta[^>]*http-equiv=["'"'"' ]*content-security-policy[^>]*>')

if [ -n "$HDR" ]; then
    echo "CSP header:"
    echo "$HDR" | sed 's/^/  /'
else
    echo "CSP header: NONE"
fi

if [ -n "$META" ]; then
    echo "CSP meta:"
    echo "$META" | sed 's/^/  /'
else
    echo "CSP meta:   NONE"
fi

if [ -n "$HDR$META" ]; then
    echo "RESULT: HAS a CSP"
    exit 0
fi

echo "RESULT: NO CSP"
exit 1
