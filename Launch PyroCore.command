#!/bin/sh
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ ! -x "$project_dir/.venv/bin/python" ]; then
    printf '%s\n' 'Set up the project environment using README.md, then run this launcher again.'
    exit 1
fi
exec "$project_dir/.venv/bin/python" "$project_dir/desktop/app.py" "$@"
