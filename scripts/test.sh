#!/bin/bash

set -e

PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Project Root: $PROJECT_ROOT"
echo "If this is . then run from root not scripts"
echo "Script Directory: $SCRIPT_DIR"