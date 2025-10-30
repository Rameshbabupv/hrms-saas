#!/bin/bash
# Convenience script to add a new project to the chat history framework

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/sync-framework.sh" add "$1" "$2"