#!/usr/bin/env bash
# Spend a CAS proxy ticket on a target URL and show what comes back.
#
# A proxy ticket is minted from a proxy granting ticket and then presented to
# the target as ?ticket=PT-... The target validates it with CAS and serves the
# request as that user. This is how a leaked PGT is turned into access.
#
# Usage: ./check-cas-proxy-ticket-access.sh <cas-base-url> <pgt> <target-url>
#
#   ./check-cas-proxy-ticket-access.sh https://auth.example.com PGT-1234-abcd \
#       https://auth.example.com/api/users/1234
#
# Exit 0 the target served the request, 1 it refused, 2 no ticket was minted.

if [ -z "$3" ]; then
    echo "Usage: $0 <cas-base-url> <pgt> <target-url>"
    exit 1
fi

CAS="${1%/}"
PGT="$2"
TARGET="$3"
B=$(mktemp)
trap 'rm -f "$B"' EXIT

PT=$(curl -sS -m 25 -G "$CAS/cas/proxy" \
        --data-urlencode "pgt=$PGT" \
        --data-urlencode "targetService=$TARGET" \
     | grep -oE "<cas:proxyTicket>[^<]+" | sed "s/.*>//")

if [ -z "$PT" ]; then
    echo "no proxy ticket minted for $TARGET"
    exit 2
fi
echo "Target: $TARGET"
echo "PT:     ${PT:0:26}..."

sep="?"
case "$TARGET" in *\?*) sep="&";; esac
code=$(curl -sS -m 25 -L -o "$B" -w "%{http_code}" "${TARGET}${sep}ticket=$PT")
echo "Status: HTTP $code  $(wc -c < "$B") bytes"

grep -oE "\"email\":\"[^\"]*\"" "$B" | head -5 | sed 's/^/  /'
grep -oE "\"name\":\"(security:manage_users|dashboard:admin|splat:admin)\"" "$B" | sort -u | sed 's/^/  /'
grep -oE "\"can_access_all\":[a-z]*" "$B" | head -1 | sed 's/^/  /'

echo
case "$code" in
    200) echo "RESULT: served. The proxy ticket granted access to $TARGET"; exit 0;;
    403) echo "RESULT: refused with 403. Authorization denied this request"; exit 1;;
    401) echo "RESULT: refused with 401. The ticket was not accepted"; exit 1;;
    *)   echo "RESULT: HTTP $code"; exit 1;;
esac
