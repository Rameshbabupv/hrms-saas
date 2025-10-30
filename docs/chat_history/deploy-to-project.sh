#!/bin/bash

# Clean Chat History Framework Deployment Script
# Deploys only the necessary framework files to a new project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Source directory (this framework location)
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Files to deploy to new projects (CLEAN LIST)
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

# Files to NEVER deploy (master/source only)
EXCLUDED_FILES=(
    "projects-registry.md"
    "sync-framework.sh"
    "add-project.sh"
    "sync-all.sh"
    "list-projects.sh"
    "SYNC-SYSTEM.md"
    "SESSION-IMPROVEMENTS.md"
    "VERSION"
    "deploy-to-project.sh"
)

show_help() {
    echo "Clean Chat History Framework Deployment"
    echo ""
    echo "Usage:"
    echo "  $0 <target_project_path> [project_name]"
    echo ""
    echo "Examples:"
    echo "  $0 /Users/rameshbabu/projects/webapp/docs/"
    echo "  $0 /Users/rameshbabu/projects/webapp/docs/ \"My Web App\""
    echo ""
    echo "This creates a clean chat_history/ directory with:"
    echo "  ✓ Framework files (CLAUDE.md, templates, etc.)"
    echo "  ✓ Empty directories for sessions, summaries, concepts"
    echo "  ✗ NO sync scripts or registry files"
    echo ""
}

deploy_framework() {
    local target_base="$1"
    local project_name="${2:-New Project}"
    
    # Validate target
    if [[ ! -d "$target_base" ]]; then
        print_error "Target directory does not exist: $target_base"
        return 1
    fi
    
    local target_dir="$target_base/chat_history"
    
    print_status "Deploying clean framework to: $target_dir"
    
    # Create directory structure
    mkdir -p "$target_dir"
    mkdir -p "$target_dir/templates"
    mkdir -p "$target_dir/sessions"
    mkdir -p "$target_dir/daily_summaries"
    mkdir -p "$target_dir/key_concepts"
    
    local files_deployed=0
    
    # Deploy framework files
    for file in "${FRAMEWORK_FILES[@]}"; do
        if [[ -f "$SOURCE_DIR/$file" ]]; then
            cp "$SOURCE_DIR/$file" "$target_dir/$file"
            print_status "  Deployed: $file"
            files_deployed=$((files_deployed + 1))
        else
            print_warning "  Source file not found: $file"
        fi
    done
    
    # Deploy template files
    for file in "${TEMPLATE_FILES[@]}"; do
        if [[ -f "$SOURCE_DIR/$file" ]]; then
            cp "$SOURCE_DIR/$file" "$target_dir/$file"
            print_status "  Deployed: $file"
            files_deployed=$((files_deployed + 1))
        else
            print_warning "  Source file not found: $file"
        fi
    done
    
    print_success "Framework deployed successfully!"
    print_success "  Files deployed: $files_deployed"
    print_success "  Location: $target_dir"
    
    # Check for project-level CLAUDE.md and add chat history section
    local project_claude_md="$(dirname "$target_dir")/CLAUDE.md"
    if [[ -f "$project_claude_md" ]]; then
        # Check if chat history section already exists
        if ! grep -q "Chat History System (MANDATORY)" "$project_claude_md"; then
            print_status "Found project CLAUDE.md - adding chat history integration..."
            
            # Add the chat history section
            cat >> "$project_claude_md" << 'EOF'

## Chat History System (MANDATORY)

**CRITICAL REQUIREMENT**: This project uses the comprehensive chat history system in `docs/chat_history/`. 

**Every Claude AI session MUST:**
1. Read `docs/chat_history/CLAUDE.md` first
2. Execute morning startup routine from `templates/morning-startup-routine.md`
3. Capture ALL significant Q&A using embedded Q&A format
4. End session with `templates/end-of-day-ceremony.md` checklist

**System Location**: All chat history files in `docs/chat_history/sessions/` and `docs/chat_history/daily_summaries/`
EOF
            print_success "  ✅ Added chat history section to project CLAUDE.md"
        else
            print_status "  ✅ Chat history section already exists in project CLAUDE.md"
        fi
    else
        print_status "  No project CLAUDE.md found - you can create one later if needed"
    fi
    
    print_success "  Project ready for chat history system"
    
    echo ""
    print_status "Next steps:"
    echo "  1. Register project: $SOURCE_DIR/add-project.sh \"$project_name\" \"$target_dir\""
    echo "  2. Start using the chat history system"
    
    return 0
}

# Main script logic
case "${1:-}" in
    "--help"|"help"|"")
        show_help
        ;;
    *)
        if [[ -z "$1" ]]; then
            print_error "Target path required"
            show_help
            exit 1
        fi
        deploy_framework "$1" "$2"
        ;;
esac