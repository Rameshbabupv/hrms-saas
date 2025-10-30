#!/bin/bash

# Creates a clean chat_history template directory for manual copying
# This creates a deployable template without master/source files

set -e

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SOURCE_DIR/clean-template"

# Clean up any existing template
rm -rf "$TEMPLATE_DIR"

# Create clean template structure
mkdir -p "$TEMPLATE_DIR/chat_history"
mkdir -p "$TEMPLATE_DIR/chat_history/templates"
mkdir -p "$TEMPLATE_DIR/chat_history/sessions"
mkdir -p "$TEMPLATE_DIR/chat_history/daily_summaries" 
mkdir -p "$TEMPLATE_DIR/chat_history/key_concepts"

# Copy only the framework files (not master/sync files)
FRAMEWORK_FILES=(
    "CLAUDE.md"
    "README.md"
    "Framework-Portability-Guide.md"
    "System_Prompt.md"
    "action_items.md"
)

TEMPLATE_FILES=(
    "templates/morning-startup-routine.md"
    "templates/interrupted-session-recovery.md"
    "templates/end-of-day-ceremony.md"
    "templates/qa-entry-template.md"
    "templates/qa-entry-template-quick.md"
    "templates/daily-summary-template.md"
    "templates/daily-summary-template-quick.md"
    "templates/session-template.md"
    "templates/concept-template.md"
    "templates/action-item-template.md"
)

echo "Creating clean template..."

# Copy framework files
for file in "${FRAMEWORK_FILES[@]}"; do
    if [[ -f "$SOURCE_DIR/$file" ]]; then
        cp "$SOURCE_DIR/$file" "$TEMPLATE_DIR/chat_history/$file"
        echo "  ✓ $file"
    fi
done

# Copy template files  
for file in "${TEMPLATE_FILES[@]}"; do
    if [[ -f "$SOURCE_DIR/$file" ]]; then
        cp "$SOURCE_DIR/$file" "$TEMPLATE_DIR/chat_history/$file"
        echo "  ✓ $file"
    fi
done

echo ""
echo "✅ Clean template created at: $TEMPLATE_DIR/"
echo ""
echo "Usage:"
echo "  cp -r $TEMPLATE_DIR/chat_history/ /path/to/your/project/docs/"
echo ""
echo "This template contains:"
echo "  ✓ All framework files (CLAUDE.md, templates, etc.)"
echo "  ✓ Empty directories for sessions, summaries, concepts"  
echo "  ✗ NO sync scripts, registry, or master files"