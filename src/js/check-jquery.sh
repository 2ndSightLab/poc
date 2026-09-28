#!/usr/bin/env bash
# What jQuery version is in a JavaScript bundle, and does it contain the
# script-execution path that makes .html() run injected script tags?
#
# jQuery .html() does not take the innerHTML fast path when the string holds a
# script tag. It falls through to append -> domManip, which extracts the script
# and hands it to globalEval, which calls eval. That is why a stored XSS payload
# of <script>...</script> executes rather than being inert markup.
#
# Versions below 3.5.0 are also affected by the htmlPrefilter XSS issue
# (CVE-2020-11022 / CVE-2020-11023).
#
# Usage: ./check-jquery.sh <js-url> [cookie]

if [ -z "$1" ]; then
    echo "Usage: $0 <js-url> [cookie]"
    exit 1
fi

URL="$1"
COOKIE="${2:-}"
B=$(mktemp)
H=$(mktemp)
trap 'rm -f "$B" "$H"' EXIT

curl -sS -D "$H" -o "$B" ${COOKIE:+-H "Cookie: $COOKIE"} "$URL" || {
    echo "request failed"
    exit 2
}

echo "URL:    $URL"
echo "Status: $(head -1 "$H" | tr -d '\r')"
echo "Bytes:  $(wc -c < "$B")"

VER=$(grep -oiE 'jQuery (JavaScript Library )?v?[0-9]+\.[0-9]+\.[0-9]+' "$B" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u | head -1)
[ -z "$VER" ] && VER=$(grep -oE 'jquery[\"'"'"']?[:= ]+[\"'"'"']?[0-9]+\.[0-9]+\.[0-9]+' "$B" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u | head -1)
echo "jQuery version: ${VER:-NOT FOUND}"

for sym in globalEval domManip htmlPrefilter; do
    printf 'symbol %-16s %s\n' "$sym" "$(grep -oF "$sym" "$B" | wc -l)"
done

GE=$(grep -oF globalEval "$B" | wc -l)
if [ "$GE" -eq 0 ]; then
    echo "RESULT: no globalEval - this bundle does not contain the script execution path"
    exit 1
fi

echo "RESULT: globalEval present - .html() will execute injected script tags"
if [ -n "$VER" ]; then
    MAJ=${VER%%.*}
    REST=${VER#*.}
    MIN=${REST%%.*}
    if [ "$MAJ" -lt 3 ] || { [ "$MAJ" -eq 3 ] && [ "$MIN" -lt 5 ]; }; then
        echo "        version $VER is below 3.5.0, also affected by CVE-2020-11022 / CVE-2020-11023"
    fi
fi
exit 0
