#!/usr/bin/env bash
# IDOR: does an endpoint return data for a tenant id the user is not authorized for?
#
# Usage: ./check-idor.sh <params-file>
#
# The params file sets these:
#   URL             everything up to the id. Works for a query string or a path:
#                     https://host.example.com/api/resource?tenant_id=
#                     https://host.example.com/api/tenants/
#   PARAM           name of the id, used for labelling output only
#   COOKIE          session cookie(s) for an authenticated low privilege user
#   AUTHORIZED_ID   an id this user IS allowed to see. This is the control.
#   UNAUTHORIZED_ID an id this user is NOT allowed to see.
. "$1"

for id in "$AUTHORIZED_ID" "$UNAUTHORIZED_ID"; do
    C=$(curl -sS -o /tmp/r.$$ -w '%{http_code}' -H "Cookie: $COOKIE" "$URL$id")
    echo "$PARAM=$id  HTTP $C  $(wc -c < /tmp/r.$$) bytes"
    head -c 200 /tmp/r.$$; echo
done
rm -f /tmp/r.$$
echo "VULNERABLE if the unauthorized id returned 200 with data"
