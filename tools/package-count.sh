#!/usr/bin/env sh

# Count packages explicitly pulled by use-package invocations

USE_PACKAGE_PATTERN="\(use-package "
SRC_PATH="../src"

RIPGREP_OUTPUT="$(rg "$USE_PACKAGE_PATTERN" "$SRC_PATH" | sort | uniq)"

PACKAGE_COUNT="$(printf '%s\n' "$RIPGREP_OUTPUT" | wc -l)"

PACKAGE_LIST="$(
    printf '%s\n' "$RIPGREP_OUTPUT" |
    sed -E 's/.*\(use-package[[:space:]]+([^[:space:])]+).*/\1/'
)"

echo "$PACKAGE_COUNT packages explicitly installed by the configuration:"

printf '%s\n' "$PACKAGE_LIST" | while IFS= read -r package; do
    echo "  - $package"
done
