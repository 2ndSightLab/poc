#!/bin/bash
# Requirements Section: ### log-turn.sh file: mem/scripts/log-turn.sh
LOG_TURN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_TURN_RC=$?
if [ "${LOG_TURN_RC}" -ne 0 ] || [ -z "${LOG_TURN_DIR}" ]; then
    printf 'ERROR: Resolve the project root before logging a turn.\n' >&2
    exit 1
fi
LOG_TURN_STAMP="$1"
if [ -z "${LOG_TURN_STAMP}" ]; then
    printf 'ERROR: Pass the turn timestamp HHMMSS as argument 1, e.g. log-turn.sh 014212 < turn.md\n' >&2
    exit 1
fi
LOG_TURN_CONTENT="$(cat)"
if [ -z "${LOG_TURN_CONTENT}" ]; then
    printf 'ERROR: Pipe the turn markdown containing prompt and response into log-turn.sh via stdin.\n' >&2
    exit 1
fi
case "${LOG_TURN_CONTENT}" in
    *'prompt:'*) ;;
    *) printf 'ERROR: Include a prompt: line with the exact request.\n' >&2; exit 1 ;;
esac
case "${LOG_TURN_CONTENT}" in
    *'response:'*) ;;
    *) printf 'ERROR: Include a response: line with the exact response.\n' >&2; exit 1 ;;
esac
LOG_TURN_AFTER="${LOG_TURN_CONTENT##*response:}"
LOG_TURN_AFTER="$(printf '%s' "${LOG_TURN_AFTER}" | tr -d '[:space:]')"
if [ -z "${LOG_TURN_AFTER}" ]; then
    printf 'ERROR: The response section is empty; record the exact response verbatim.\n' >&2
    exit 1
fi
LOG_TURN_DATE="$(date -u +%Y%m%d)"
LOG_TURN_RC=$?
if [ "${LOG_TURN_RC}" -ne 0 ]; then
    printf 'ERROR: date failed; cannot resolve the memory directory.\n' >&2
    exit 1
fi
mkdir -p "${LOG_TURN_DIR}/mem/${LOG_TURN_DATE}"
LOG_TURN_RC=$?
if [ "${LOG_TURN_RC}" -ne 0 ]; then
    printf 'ERROR: Create mem/%s before logging the turn.\n' "${LOG_TURN_DATE}" >&2
    exit 1
fi
printf '%s\n' "${LOG_TURN_CONTENT}" > "${LOG_TURN_DIR}/mem/${LOG_TURN_DATE}/${LOG_TURN_STAMP}.md"
LOG_TURN_RC=$?
if [ "${LOG_TURN_RC}" -ne 0 ]; then
    printf 'ERROR: Write mem/%s/%s.md failed; check permissions.\n' "${LOG_TURN_DATE}" "${LOG_TURN_STAMP}" >&2
    exit 1
fi
printf 'mem/%s/%s.md\n' "${LOG_TURN_DATE}" "${LOG_TURN_STAMP}"
