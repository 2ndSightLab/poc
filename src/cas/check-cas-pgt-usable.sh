#!/usr/bin/env bash
# Can a leaked CAS proxy granting ticket actually be used?
#
# A PGT is only dangerous if CAS still honours it. This asks the CAS server to
# mint a proxy ticket for a target service using the PGT. If CAS returns a
# proxy ticket the PGT is live and the leak is credential theft. If CAS returns
# proxyFailure the ticket is not usable and the leak is disclosure only.
#
# The PGT used must be one you are authorised to hold. Do not run this with a
# ticket belonging to another user.
#
# Usage: ./ruby-check-cas-pgt-usable.sh <cas-base-url> <pgt> <target-service-url> [service-ticket]
#
#   ./ruby-check-cas-pgt-usable.sh https://auth.example.com PGT-1234-abcd https://app.example.com/ ST-1234-efgh
#
# Exit 0 proxy ticket issued, PGT is live.
# Exit 1 CAS refused, PGT not usable.
# Exit 2 no CAS response understood.

if [ -z "$3" ]; then
    echo "Usage: $0 <cas-base-url> <pgt> <target-service-url> [service-ticket]"
    exit 1
fi

CAS="${1%/}"
PGT="$2"
TARGET="$3"
ST="${4:-}"   # optional service ticket from the same page, used as an age check
R=$(mktemp)
trap 'rm -f "$R"' EXIT

echo "CAS:    $CAS"
echo "PGT:    ${PGT:0:22}... (length ${#PGT})"
echo "Target: $TARGET"

# The service ticket from the same session is checked first. If CAS has already
# dropped that, the PGT beside it is almost certainly gone for the same reason,
# and the BAD_PGT below is expiry rather than the ticket never having worked.
if [ -n "$ST" ]; then
    curl -sS -m 25 -G "$CAS/cas/serviceValidate" \
        --data-urlencode "ticket=$ST" --data-urlencode "service=$TARGET" -o "$R" -w '' 2>/dev/null
    if grep -q "INVALID_TICKET" "$R"; then
        echo "  service ticket from the same session: INVALID_TICKET, already consumed or expired"
    elif grep -q "authenticationSuccess" "$R"; then
        echo "  service ticket from the same session: still valid"
    fi
fi

for path in /cas/proxy /cas//proxy; do
    code=$(curl -sS -m 25 -G "$CAS$path" \
        --data-urlencode "pgt=$PGT" \
        --data-urlencode "targetService=$TARGET" \
        -o "$R" -w '%{http_code}')

    PT=$(grep -oE "<cas:proxyTicket>[^<]+" "$R" | sed 's/.*>//')
    FAIL=$(grep -oE '<cas:proxyFailure code="[^"]+"[^>]*>[^<]*' "$R" | sed 's/<[^>]*>//g')
    FCODE=$(grep -oE 'code="[^"]+"' "$R" | head -1 | cut -d\" -f2)

    if [ -n "$PT" ]; then
        echo "  $path  HTTP $code  PROXY TICKET ISSUED: ${PT:0:24}..."
        echo
        echo "RESULT: the PGT is LIVE. CAS minted a ticket for $TARGET."
        echo "        A leak of this ticket is reusable credential material."
        exit 0
    fi
    if [ -n "$FCODE" ]; then
        echo "  $path  HTTP $code  refused, code $FCODE ${FAIL:+- $FAIL}"
    else
        echo "  $path  HTTP $code  no proxy ticket and no failure code"
    fi
done

echo
if [ -n "$FCODE" ]; then
    echo "RESULT: CAS refused the ticket, code $FCODE. The PGT is not usable,"
    echo "        so the leak is disclosure rather than reusable credentials."
    exit 1
fi
echo "RESULT: no CAS proxy response could be interpreted."
exit 2
