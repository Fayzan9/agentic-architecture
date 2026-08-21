#!/usr/bin/env bash
# Fetches (or refreshes) the vendored SDK source repos under docs/sources/.
# These are gitignored on purpose — this repo tracks our own reference maps
# (docs/sources/*-reference.md) and architecture docs, not copies of the SDKs
# themselves. Run this after cloning, and re-run any time (e.g. via a daily
# cron job) to pick up upstream changes.
#
# Usage: ./scripts/fetch-docs.sh
#
# Written for portability with bash 3.2 (macOS's default /bin/bash), which
# lacks associative arrays — hence the parallel-array approach below.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCES_DIR="$REPO_ROOT/docs/sources"

NAMES=(adk-python openai-agents-python claude-agent-sdk-python)
URLS=(
  "https://github.com/google/adk-python"
  "https://github.com/openai/openai-agents-python"
  "https://github.com/anthropics/claude-agent-sdk-python"
)

mkdir -p "$SOURCES_DIR"

for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  url="${URLS[$i]}"
  target="$SOURCES_DIR/$name"

  if [ -d "$target/.git" ]; then
    echo "==> Updating $name..."
    git -C "$target" fetch --depth 1 origin
    git -C "$target" reset --hard origin/HEAD
  else
    echo "==> Cloning $name..."
    rm -rf "$target"
    git clone --depth 1 "$url" "$target"
  fi
done

echo "Done. Vendored sources are up to date under docs/sources/."
