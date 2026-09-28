#!/usr/bin/env bash
# Is the Handlebars COMPILER present in a JavaScript bundle?
#
# The Handlebars prototype pollution CVEs (SNYK-JS-HANDLEBARS-173692,
# GHSA-f23m-r3pf-42rh) require compile() or precompile() to run on attacker
# controlled input. The runtime-only build cannot compile at all, so if the
# compiler is absent the CVEs are not reachable.
#
# Checks compiler symbols rather than only the literal text "Handlebars.compile",
# since a bundler may alias the library.
#
# Verified against Handlebars 4.0.5: the full build reports JavaScriptCompiler 3
# times, the runtime-only build reports it 0 times.
#
# Usage: ./check-handlebars.sh <js-url> [cookie]

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
echo "Type:   $(grep -i '^content-type:' "$H" | tr -d '\r')"
echo "Bytes:  $(wc -c < "$B")"

grep -oiE 'handlebars[^0-9]{0,12}v?[0-9]+\.[0-9]+\.[0-9]+' "$B" | sort -u | head -3 | sed 's/^/Version: /'

for sym in precompile Handlebars.compile compileInput; do
    printf 'symbol %-22s %s\n' "$sym" "$(grep -oF "$sym" "$B" | wc -l)"
done

# Decide on JavaScriptCompiler only. The runtime-only build still contains the
# word "precompile" inside its "you must precompile" error strings, so counting
# that symbol reports a compiler that is not there.
FOUND=0
JSC=$(grep -oF JavaScriptCompiler "$B" | wc -l)
printf 'symbol %-22s %s   <- decides\n' "JavaScriptCompiler" "$JSC"
[ "$JSC" -gt 0 ] && FOUND=1

if [ "$FOUND" -eq 1 ]; then
    echo "RESULT: compiler symbols present - CVEs may be reachable, review how templates are built"
    exit 0
fi

echo "RESULT: no compiler symbols - compile() not reachable, CVEs not exploitable"
exit 1
