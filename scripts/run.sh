#!/usr/bin/env bash
# Workflow commands: compile | benchmark | test | reset
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"

pillow_export_paths
pillow_load_env

COMMAND="${1:?command required}"
shift

TASK_IDS=()
FORCE=false
EXTRA=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force) FORCE=true; shift ;;
        *__*) TASK_IDS+=("$1"); shift ;;
        *) EXTRA+=("$1"); shift ;;
    esac
done

if [[ ${#TASK_IDS[@]} -eq 0 ]]; then
    case "$COMMAND" in
        compile|benchmark|test|reset)
            active="$(pillow_active_task_id)"
            if [[ -z "$active" ]]; then
                echo "No active task. Prepare one first, e.g.:" >&2
                echo "  ./compile python-pillow__Pillow-63f398b" >&2
                exit 1
            fi
            TASK_IDS=("$active")
            ;;
        *)
            echo "Unknown command: $COMMAND" >&2
            exit 1
            ;;
    esac
fi

PREPARE_EXTRA=()
[[ "$FORCE" == true ]] && PREPARE_EXTRA+=(--force)

run_prepare() {
    local task="$1"
    local quiet="${2:-0}"
    local args=(setup "$task" "${PREPARE_EXTRA[@]}")
    if [[ "$quiet" == "1" ]]; then
        GSO_QUIET_PREPARE=1 pillow_workflow "${args[@]}"
    else
        pillow_workflow "${args[@]}"
    fi
}

show_summary() {
    local task="$1"
    local summary="${PILLOW_ROOT}/summary.txt"
    if [[ -f "$summary" ]]; then
        echo ""
        echo "--- ${task} ---"
        cat "$summary"
    fi
}

failures=()

echo "=== ${COMMAND} (${#TASK_IDS[@]} task(s)) ==="
echo "project/: ${GSO_PROJECT_ROOT}/"
[[ ${#TASK_IDS[@]} -gt 1 ]] && export GSO_ALLOW_TASK_SWITCH=1
pillow_print_status

for task in "${TASK_IDS[@]}"; do
    echo ""
    echo ">> ${task}"
    case "$COMMAND" in
        compile)
            run_prepare "$task" 1 || { failures+=("$task"); continue; }
            pillow_workflow patch "$task" \
                --model-name local-edit \
                --placeholder-on-unchanged || failures+=("$task")
            ;;
        benchmark)
            # Prepare syncs project/ to the task commit (preserving edits when HEAD matches).
            run_prepare "$task" 1 || { failures+=("$task"); continue; }
            if pillow_workflow benchmark "$task" "${EXTRA[@]}"; then
                show_summary "$task"
            else
                failures+=("$task")
            fi
            ;;
        test)
            run_prepare "$task" 1 || { failures+=("$task"); continue; }
            pillow_workflow test "$task" "${EXTRA[@]}" || failures+=("$task")
            ;;
        reset)
            pillow_workflow reset "$task" || failures+=("$task")
            ;;
        *)
            echo "Unknown command: $COMMAND" >&2
            exit 1
            ;;
    esac
done

echo ""
if ((${#failures[@]} > 0)); then
    echo "Failed: ${failures[*]}"
    exit 1
fi
echo "Done (${#TASK_IDS[@]} task(s))."
