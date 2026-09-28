#!/usr/bin/env bash
# Does a Rails error page leak session and authentication material?
#
# A Rails debug page renders the session hash and the request environment below
# the stack trace. Where CAS single sign on is in use that includes live
# credentials, not only internal paths and versions.
#
# The CAS proxy granting ticket is the one that matters most. A service ticket
# is single use and tied to one application. A PGT is long lived and lets its
# holder ask CAS to mint fresh service tickets for other applications in the
# estate, acting as that user. Leaking one is not leaking a session, it is
# leaking the ability to keep minting access.
#
# Each check prints the matched value, truncated, so the output is evidence
# rather than an assertion. Secrets are cut to a short prefix on purpose.
#
# Read only. Nothing found is used.
#
# Usage: ./check-error-page-session-leak.sh <url> [cookie]

if [ -z "$1" ]; then
    echo "Usage: $0 <url> [cookie]"
    exit 1
fi

URL="$1"
COOKIE="${2:-}"
B=$(mktemp)
trap 'rm -f "$B"' EXIT

code=$(curl -sS -m 30 -o "$B" -w '%{http_code}' ${COOKIE:+-H "Cookie: $COOKIE"} "$URL")
echo "URL:    $URL"
echo "Status: HTTP $code"
echo "Bytes:  $(wc -c < "$B")"

# Only a Rails debug page renders the session. Anything else is a different bug.
if ! grep -qE "Action Controller: Exception caught|Rails\.root" "$B"; then
    echo "RESULT: not a Rails debug page, nothing to assess here."
    exit 1
fi

HITS=0
show() { # label, regex, how many characters of the match to print
    v=$(grep -oiE "$2" "$B" 2>/dev/null | head -1)
    if [ -n "$v" ]; then
        echo "  LEAK  $1"
        echo "          ${v:0:$3}..."
        HITS=$((HITS+1))
    fi
}

echo "--- live authentication material ---"
show "CAS proxy granting ticket, mints tickets for other CAS applications" "PGT-[0-9]{8,}-[A-Za-z0-9]+" 24
show "CAS PGTIOU, the handle used to retrieve that PGT"                    "PGTIOU-[0-9]{8,}-[A-Za-z0-9]+" 28
show "CAS service ticket"                                                  "ST-[0-9]{8,}-[A-Za-z0-9]+" 22
show "authenticated user name held by the CAS filter"                      "casfilteruser[^A-Za-z0-9]{1,8}[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+" 40
show "serialized user object, internal ids and platform roles"             "SecurityUser:0x[0-9a-f]+|accessible_company_ids[^A-Za-z]{1,8}\\[[0-9, ]+\\]" 45
show "session identifier rendered into the page body"                      "(_session_id|ss-[a-z0-9]+)[^A-Za-z0-9]{1,8}[A-Za-z0-9]{6,}" 30

echo "--- deployment detail ---"
show "framework root path"                                     "Rails\.root:[^<]{1,60}" 60
show "client address as the application sees it"               "REMOTE_ADDR[^A-Za-z0-9]{1,8}[0-9.]+" 34

APPSRC=$(grep -oE "app/(controllers|models|views|helpers|lib)/[a-z0-9_/]+\.rb:[0-9]+" "$B" | sort -u)
if [ -n "$APPSRC" ]; then
    echo "  LEAK  application source, not framework code"
    echo "$APPSRC" | sed 's/^/          /'
    HITS=$((HITS+1))
fi

echo
if grep -qE "PGT-[0-9]{8,}" "$B"; then
    echo "RESULT: $HITS categories leaked, including a CAS proxy granting ticket."
    echo "        That is reusable credential material, not just a disclosure."
    exit 0
fi
if [ "$HITS" -gt 0 ]; then
    echo "RESULT: $HITS categories leaked, no proxy granting ticket present."
    exit 0
fi
echo "RESULT: Rails debug page, but no session or authentication material on it."
exit 1
