#!/bin/bash

source "logging.sh"

skip_mypy=(
    "./logging_helper.py"
)

failed=0
log_progress "Linting ci_parser..."
for i in `find . -maxdepth 1 -name "*.py"`; do
    log_progress "Checking $i..."
    flake8 "$i"
    if [[ $? != 0 ]]; then
        failed=1
    fi

    if [[ ! " ${skip_mypy[*]} " =~ ${i} ]]; then
        mypy --ignore-missing-imports "$i"
        if [[ $? != 0 ]]; then
            failed=1
        fi
    fi
done


if [[ $failed -eq 1 ]]; then
    log_error "Failed linting. See above errors; don't merge until clean."
    exit 1
else
    log_progress "All scripts passed checks"
    exit 0
fi
