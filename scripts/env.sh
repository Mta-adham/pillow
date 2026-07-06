#!/usr/bin/env bash
# Paths and helpers for the pillow benchmark hub (self-contained).

pillow_hub_root() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$here/.." && pwd
}

pillow_export_paths() {
    local hub
    hub="$(pillow_hub_root)"
    export PILLOW_ROOT="$hub"
    export GSO_WORKSPACE_ROOT="$hub"
    export GSO_PROJECT_ROOT="$hub/project"
}

pillow_workflow_py() {
    local hub="${PILLOW_ROOT:-$(pillow_hub_root)}"
    local wf="$hub/scripts/workflow.py"
    if [[ ! -f "$wf" ]]; then
        echo "workflow not found: $wf" >&2
        return 1
    fi
    echo "$wf"
}

# Load HF_TOKEN etc. from hub .env only.
pillow_load_env() {
    local hub
    hub="$(pillow_hub_root)"
    if [[ -f "$hub/.env" ]]; then
        set -a
        # shellcheck disable=SC1091
        source "$hub/.env"
        set +a
    fi
}

pillow_list_tasks() {
    GSO_WORKSPACE_ROOT="${PILLOW_ROOT}" python3 "${PILLOW_ROOT}/scripts/hub.py" list
}

pillow_task_ids() {
    pillow_list_tasks | awk -F'\t' '{print $1}'
}

pillow_workflow() {
    local wf
    wf="$(pillow_workflow_py)"
    export GSO_WORKSPACE_ROOT="${PILLOW_ROOT}"
    PYTHONPATH="$(dirname "$wf")${PYTHONPATH:+:$PYTHONPATH}" python3 "$wf" "$@"
}

pillow_workflow_eval() {
    local py_expr="$1"
    local wf
    wf="$(pillow_workflow_py)"
    export GSO_WORKSPACE_ROOT="${PILLOW_ROOT}"
    PYTHONPATH="$(dirname "$wf")" python3 -c "
import importlib.util
spec = importlib.util.spec_from_file_location('gso_workflow', '${wf}')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
${py_expr}
"
}

pillow_print_status() {
    pillow_workflow_eval "print(m.format_active_task_status())" 2>/dev/null || true
}

pillow_active_task_id() {
    GSO_WORKSPACE_ROOT="${PILLOW_ROOT}" python3 -c "
import os, yaml
from pathlib import Path
p = Path(os.environ['GSO_WORKSPACE_ROOT']) / '.gso_task_id'
if not p.is_file():
    print('')
else:
    data = yaml.safe_load(p.read_text()) or {}
    print(data.get('instance_id') or '')
"
}
