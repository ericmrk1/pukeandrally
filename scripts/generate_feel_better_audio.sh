#!/bin/bash
# Generate "Wow, I feel better" TTS for the throw-up emoji. Requires macOS (uses `say`).
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$(cd "$SCRIPT_DIR/../UltraRunner" && pwd)"
OUT="$OUT_DIR/feel_better.aiff"
say -o "$OUT" "Wow, I feel better"
echo "Wrote $OUT"
