#!/usr/bin/env bash
# Docker image commands: pull-images | verify-images | pin-images
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"

pillow_export_paths
pillow_load_env

CMD="${1:?command required}"
shift

case "$CMD" in
    pull-images)   ACTION=pull ;;
    verify-images) ACTION=verify ;;
    pin-images)    ACTION=pin ;;
    *)
        echo "Unknown command: $CMD" >&2
        exit 1
        ;;
esac

TASK_IDS=()
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force) FORCE=true; shift ;;
        *__*) TASK_IDS+=("$1"); shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ ${#TASK_IDS[@]} -eq 0 ]]; then
    mapfile -t TASK_IDS < <(pillow_task_ids)
fi
if [[ ${#TASK_IDS[@]} -eq 0 ]]; then
    echo "No tasks in ${PILLOW_ROOT}/benchmarks/" >&2
    exit 1
fi

EXTRA=()
[[ "$FORCE" == true && "$ACTION" == verify ]] && EXTRA+=(--force)

echo "=== ${CMD} (${#TASK_IDS[@]} task(s)) ==="

for task in "${TASK_IDS[@]}"; do
    echo ">> ${task}"
    GSO_WORKSPACE_ROOT="${PILLOW_ROOT}" \
        python3 "${PILLOW_ROOT}/scripts/hub.py" "$ACTION" "$task" "${EXTRA[@]}"
done

echo ""
echo "Done."
