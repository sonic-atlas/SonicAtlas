#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

if [ -f "build/gcc-debug/compile_commands.json" ]; then
    sed -i 's/-mno-direct-extern-access//g' build/gcc-debug/compile_commands.json
fi

find src -name "*.cpp" -o -name "*.hpp" | xargs clang-format --style=file --fallback-style=none -i
find src -name "*.cpp" | xargs -n 1 -P $(nproc) clang-tidy -p build/gcc-debug
