#!/bin/bash
# Requirements Section: ### check-turn.sh file: mem/scripts/check-turn.sh
CHECK_TURN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECK_TURN_RC=$?
if [ "${CHECK_TURN_RC}" -ne 0 ] || [ -z "${CHECK_TURN_DIR}" ]; then
    printf 'ERROR: Resolve the project root before checking the turn.\n' >&2
    exit 1
fi
if [ ! -f "${CHECK_TURN_DIR}/time.md" ]; then
    printf 'ERROR: time.md is missing; log the turn time before checking.\n' >&2
    exit 1
fi
CHECK_TURN_LINE="$(head -1 "${CHECK_TURN_DIR}/time.md")"
CHECK_TURN_RC=$?
if [ "${CHECK_TURN_RC}" -ne 0 ] || [ -z "${CHECK_TURN_LINE}" ]; then
    printf 'ERROR: Could not read the top line of time.md.\n' >&2
    exit 1
fi
CHECK_TURN_RE='^start:[^ ]+ stop:[^ ]+ req_words:[0-9]+ resp_words:[0-9]+ est_tokens:~[0-9]+ req:\+[0-9]+a/-[0-9]+r code:\+[0-9]+a/-[0-9]+r rework:[0-9]+ desc:.+ total:~[0-9]+s overhead:~[0-9]+s$'
if [[ ! "${CHECK_TURN_LINE}" =~ ${CHECK_TURN_RE} ]]; then
    printf 'ERROR: Top time.md line does not match the required format; fix log-time.sh output before ending the turn.\n' >&2
    exit 1
fi
printf 'OK: latest time.md line conforms to the required format.\n'
