#!/bin/bash
# Requirements Section: ### end-turn.sh file: mem/scripts/end-turn.sh
END_TURN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ $? -ne 0 ] || [ -z "${END_TURN_DIR}" ]; then
    printf 'ERROR: Resolve the project root before ending the turn.\n' >&2
    exit 1
fi
END_TURN_INJECTED="$1"
END_TURN_REQ="$2"
END_TURN_RESP="$3"
END_TURN_METRICS="$4"
if [ -z "${END_TURN_INJECTED}" ] || [ -z "${END_TURN_REQ}" ] || [ -z "${END_TURN_RESP}" ] || [ -z "${END_TURN_METRICS}" ]; then
    printf 'ERROR: Usage: end-turn.sh INJECTED_ISO REQ_WORDS RESP_WORDS "req:+a/-r code:+a/-r rework:N desc:..." < turn.md\n' >&2
    exit 1
fi
END_TURN_START_FILE="/tmp/$(id -u)-botz-turn-start"
if [ ! -f "${END_TURN_START_FILE}" ]; then
    printf 'ERROR: Missing %s; run mem/scripts/start-turn.sh at the start of the turn.\n' "${END_TURN_START_FILE}" >&2
    exit 1
fi
END_TURN_START="$(cat "${END_TURN_START_FILE}")"
if [ -z "${END_TURN_START}" ]; then
    printf 'ERROR: The recorded turn start epoch is empty; rerun mem/scripts/start-turn.sh.\n' >&2
    exit 1
fi
END_TURN_CONTENT="$(cat)"
if [ -z "${END_TURN_CONTENT}" ]; then
    printf 'ERROR: Pipe the turn markdown (prompt and response) into end-turn.sh via stdin.\n' >&2
    exit 1
fi
bash "${END_TURN_DIR}/mem/scripts/log-time.sh" "${END_TURN_INJECTED}" "${END_TURN_START}" "${END_TURN_REQ}" "${END_TURN_RESP}" "${END_TURN_METRICS}" >/dev/null
if [ $? -ne 0 ]; then
    printf 'ERROR: log-time.sh failed; fix the time line before finishing.\n' >&2
    exit 1
fi
printf '%s' "${END_TURN_CONTENT}" | bash "${END_TURN_DIR}/mem/scripts/log-turn.sh" "$(date -u +%H%M%S)" >/dev/null
if [ $? -ne 0 ]; then
    printf 'ERROR: log-turn.sh failed; ensure a prompt and a non-empty response are present.\n' >&2
    exit 1
fi
bash "${END_TURN_DIR}/mem/scripts/check-turn.sh" >/dev/null
if [ $? -ne 0 ]; then
    printf 'ERROR: check-turn.sh failed; the time.md line does not conform.\n' >&2
    exit 1
fi
printf 'TURN LOGGED\n'
