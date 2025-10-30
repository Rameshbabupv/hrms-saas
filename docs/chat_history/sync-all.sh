#!/bin/bash
# Convenience script to sync framework to all registered projects

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/sync-framework.sh" all