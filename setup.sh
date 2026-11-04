#!/usr/bin/env bash
# One-step PyroCore setup: create .venv, install dependencies, flash the board.
set -eo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_dir"

venv="$project_dir/.venv"
python="$venv/bin/python"

usage() {
    cat <<'EOF'
Usage: ./setup.sh [--no-flash | --flash-only] [flash options]

Creates .venv, installs dependencies, then flashes the prebuilt release.
Other options are passed to tools/flash_release.py, for example:
  ./setup.sh --port COM5
  ./setup.sh --list-ports
  ./setup.sh --dry-run

  --no-flash     Set up the environment only; do not flash.
  --flash-only   Install only esptool/pyserial (skip the desktop app).
  -h, --help     Show this help.
EOF
}

find_python() {
    for candidate in python3.13 python3.12 python3.11 python3.10 python3.9 python3; do
        if command -v "$candidate" >/dev/null 2>&1; then
            if "$candidate" -c 'import sys; raise SystemExit(0 if (3, 9) <= sys.version_info[:2] < (3, 14) else 1)' 2>/dev/null; then
                printf '%s\n' "$candidate"
                return 0
            fi
        fi
    done
    return 1
}

flash=1
flash_only=0
forward=()
for argument in "$@"; do
    case "$argument" in
        -h|--help) usage; exit 0 ;;
        --no-flash) flash=0 ;;
        --flash-only) flash_only=1 ;;
        *) forward+=("$argument") ;;
    esac
done

if [ ! -x "$python" ]; then
    if ! selected="$(find_python)"; then
        printf '%s\n' 'Python 3.9-3.13 is required. Install it, then run ./setup.sh again.' >&2
        exit 1
    fi
    printf 'Creating .venv with %s\n' "$("$selected" --version 2>&1)"
    "$selected" -m venv "$venv"
fi

printf 'Installing dependencies...\n'
if [ "$flash_only" -eq 0 ]; then
    "$python" -m pip install --disable-pip-version-check -q -r desktop/requirements.txt
fi
"$python" -m pip install --disable-pip-version-check -q -r tools/requirements-flash.txt

if [ "$flash" -eq 0 ]; then
    printf '\nSetup complete. Flash with:\n  .venv/bin/python tools/flash_release.py\n'
    exit 0
fi

printf '\n'
if [ "${#forward[@]}" -gt 0 ]; then
    "$python" tools/flash_release.py "${forward[@]}"
else
    "$python" tools/flash_release.py
fi

if [ "$flash_only" -eq 0 ]; then
    printf '\nStart the desktop app with:\n  .venv/bin/python desktop/app.py\n'
else
    printf '\nFlash-only setup. Add the desktop app later with:\n'
    printf '  .venv/bin/python -m pip install -r desktop/requirements.txt\n'
fi
