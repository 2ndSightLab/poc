#!/usr/bin/env bash
# Is a Rails application actually running in the development environment?
#
# This is the precondition for CVE-2019-5420, remote code execution through a
# guessable development mode secret_key_base. A development style error page on
# its own does NOT prove development mode, because consider_all_requests_local
# can be enabled in any environment. These checks look for behaviour that only
# the development environment produces.
#
# Read only. It does not attempt exploitation.
#
# Usage: ./check-rails-dev-mode.sh <base-url>

if [ -z "$1" ]; then
    echo "Usage: $0 <base-url>"
    exit 1
fi

BASE="${1%/}"
B=$(mktemp); H=$(mktemp)
trap 'rm -f "$B" "$H"' EXIT
HITS=0

probe() { # path, description, pattern that only development produces
    code=$(curl -sS -m 20 -D "$H" -o "$B" -w '%{http_code}' "$BASE$1")
    if [ "$code" = "200" ] && grep -qiE "$3" "$B"; then
        echo "  DEV INDICATOR  $1  HTTP $code  $2"
        HITS=$((HITS+1))
    else
        echo "  no             $1  HTTP $code  $2"
    fi
}

echo "Base: $BASE"

# Mounted only when Rails.env.development? is true
probe "/rails/info/properties" "Rails::Info properties page" "Ruby version|Rails version|Environment"
probe "/rails/info/routes"     "route listing"               "Helper|HTTP Verb|Path / Url"
probe "/rails/info"            "Rails::Info index"           "Rails version|Ruby version"

# Context only, NOT a development indicator. The Routing Error template is
# rendered by ActionDispatch::DebugExceptions whenever consider_all_requests_local
# is true, which can be set in any environment.
code=$(curl -sS -m 20 -o "$B" -w '%{http_code}' "$BASE/zzz-no-such-route-$RANDOM")
if grep -qiE "Routing Error|No route matches" "$B"; then
    echo "  context        debug exception pages are enabled (consider_all_requests_local)  HTTP $code"
else
    echo "  context        unknown route returns a plain page  HTTP $code  $(wc -c < "$B") bytes"
fi

echo
if [ "$HITS" -gt 0 ]; then
    echo "RESULT: development mode indicators found ($HITS). CVE-2019-5420 may apply."
    exit 0
fi
echo "RESULT: no development mode indicators. The debug page is most likely"
echo "        consider_all_requests_local enabled outside development, so"
echo "        CVE-2019-5420 does not apply."
exit 1
