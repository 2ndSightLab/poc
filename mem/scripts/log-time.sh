#!/bin/bash
# Requirements Section: ### log-time.sh file: mem/scripts/log-time.sh
LOG_TIME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_TIME_RC=$?
if [ "${LOG_TIME_RC}" -ne 0 ] || [ -z "${LOG_TIME_DIR}" ]; then
    printf 'ERROR: Resolve the project root before logging time.\n' >&2
    exit 1
fi
LOG_TIME_INJECTED="$1"
LOG_TIME_START_EPOCH="$2"
LOG_TIME_REQ_WORDS="$3"
LOG_TIME_RESP_WORDS="$4"
LOG_TIME_METRICS="$5"
if [ -z "${LOG_TIME_INJECTED}" ] || [ -z "${LOG_TIME_START_EPOCH}" ] || [ -z "${LOG_TIME_REQ_WORDS}" ] || [ -z "${LOG_TIME_RESP_WORDS}" ] || [ -z "${LOG_TIME_METRICS}" ]; then
    printf 'ERROR: Usage: log-time.sh INJECTED_ISO START_EPOCH REQ_WORDS RESP_WORDS "req:+a/-r code:+a/-r rework:N desc:...".\n' >&2
    exit 1
fi
for LOG_TIME_NUM in "${LOG_TIME_START_EPOCH}" "${LOG_TIME_REQ_WORDS}" "${LOG_TIME_RESP_WORDS}"; do
    if [[ ! "${LOG_TIME_NUM}" =~ ^[0-9]+$ ]]; then
        printf 'ERROR: START_EPOCH, REQ_WORDS, and RESP_WORDS must be integers.\n' >&2
        exit 1
    fi
done
LOG_TIME_INJ_EPOCH="$(date -u -d "${LOG_TIME_INJECTED}" +%s)"
LOG_TIME_RC=$?
if [ "${LOG_TIME_RC}" -ne 0 ] || [ -z "${LOG_TIME_INJ_EPOCH}" ]; then
    printf 'ERROR: Could not parse injected datetime "%s"; pass the exact injected timestamp.\n' "${LOG_TIME_INJECTED}" >&2
    exit 1
fi
LOG_TIME_NOW_EPOCH="$(date -u +%s)"
LOG_TIME_START="$(date -u -d "@${LOG_TIME_START_EPOCH}" +%Y-%m-%dT%H:%M:%SZ)"
LOG_TIME_STOP="$(date -u -d "@${LOG_TIME_NOW_EPOCH}" +%Y-%m-%dT%H:%M:%SZ)"
LOG_TIME_OVERHEAD=$((LOG_TIME_START_EPOCH - LOG_TIME_INJ_EPOCH))
LOG_TIME_TOTAL=$((LOG_TIME_NOW_EPOCH - LOG_TIME_INJ_EPOCH))
LOG_TIME_TOK=$(((LOG_TIME_REQ_WORDS + LOG_TIME_RESP_WORDS) * 13 / 10))
LOG_TIME_LINE="start:${LOG_TIME_START} stop:${LOG_TIME_STOP} req_words:${LOG_TIME_REQ_WORDS} resp_words:${LOG_TIME_RESP_WORDS} est_tokens:~${LOG_TIME_TOK} ${LOG_TIME_METRICS} total:~${LOG_TIME_TOTAL}s overhead:~${LOG_TIME_OVERHEAD}s"
LOG_TIME_TMP="$(mktemp)"
LOG_TIME_RC=$?
if [ "${LOG_TIME_RC}" -ne 0 ] || [ -z "${LOG_TIME_TMP}" ]; then
    printf 'ERROR: Could not create a temp file to prepend time.md.\n' >&2
    exit 1
fi
printf '%s\n' "${LOG_TIME_LINE}" > "${LOG_TIME_TMP}"
if [ -f "${LOG_TIME_DIR}/time.md" ]; then
    cat "${LOG_TIME_DIR}/time.md" >> "${LOG_TIME_TMP}"
    LOG_TIME_RC=$?
    if [ "${LOG_TIME_RC}" -ne 0 ]; then
        rm -f "${LOG_TIME_TMP}"
        printf 'ERROR: Failed to read time.md while prepending; check read permission on time.md.\n' >&2
        exit 1
    fi
fi
cp "${LOG_TIME_TMP}" "${LOG_TIME_DIR}/time.md"
LOG_TIME_RC=$?
rm -f "${LOG_TIME_TMP}"
if [ "${LOG_TIME_RC}" -ne 0 ]; then
    printf 'ERROR: Failed to write time.md; check write permission on time.md.\n' >&2
    exit 1
fi
printf '%s\n' "${LOG_TIME_LINE}"
