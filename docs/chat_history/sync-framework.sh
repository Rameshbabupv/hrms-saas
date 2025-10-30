#!/bin/bash

# Chat History Framework Sync Script
# Safely updates framework files while preserving session data

set -e  # Exit on any error

SOURCE_DIR="/Users/rameshbabu/data/projects/personnel/deploy/docs/chat_history"
REGISTRY_FILE="$SOURCE_DIR/projects-registry.md"
CURRENT_VERSION="v3.1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Framework files that are safe to overwrite
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

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to extract project paths from registry
get_project_paths() {
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        print_error "Registry file not found: $REGISTRY_FILE"
        exit 1
    fi
    
    # Extract paths from registry table (skip header and empty lines)
    grep "^|" "$REGISTRY_FILE" | \
    grep -v "Project Name\|---\|SOURCE" | \
    sed 's/^|[^|]*|[[:space:]]*\([^|]*\)[[:space:]]*|.*$/\1/' | \
    sed 's/^[[:space:]]*`\(.*\)`[[:space:]]*$/\1/' | \
    grep -v "^[[:space:]]*$"
}

# Function to sync framework files to a single project
sync_project() {
    local target_path="$1"
    local project_name="$2"
    
    if [[ ! -d "$target_path" ]]; then
        print_warning "Target directory does not exist: $target_path"
        return 1
    fi
    
    print_status "Syncing framework to: $project_name ($target_path)"
    
    # Create templates directory if it doesn't exist
    mkdir -p "$target_path/templates"
    
    # Sync framework files
    local files_updated=0
    
    for file in "${FRAMEWORK_FILES[@]}"; do
        if [[ -f "$SOURCE_DIR/$file" ]]; then
            cp "$SOURCE_DIR/$file" "$target_path/$file"
            files_updated=$((files_updated + 1))
            print_status "  Updated: $file"
        else
            print_warning "  Source file not found: $file"
        fi
    done
    
    # Sync template files
    for file in "${TEMPLATE_FILES[@]}"; do
        if [[ -f "$SOURCE_DIR/$file" ]]; then
            cp "$SOURCE_DIR/$file" "$target_path/$file"
            files_updated=$((files_updated + 1))
            print_status "  Updated: $file"
        else
            print_warning "  Source file not found: $file"
        fi
    done
    
    # Ensure data directories exist but don't touch their contents
    mkdir -p "$target_path/sessions"
    mkdir -p "$target_path/daily_summaries"
    mkdir -p "$target_path/key_concepts"
    
    # Check for project-level CLAUDE.md and add chat history section if needed
    local project_claude_md="$(dirname "$target_path")/CLAUDE.md"
    if [[ -f "$project_claude_md" ]]; then
        # Check if chat history section already exists
        if ! grep -q "Chat History System (MANDATORY)" "$project_claude_md"; then
            print_status "  Adding chat history integration to project CLAUDE.md..."
            
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
            print_status "  ✅ Added chat history section to project CLAUDE.md"
        fi
    fi
    
    print_success "  Synced $files_updated files to $project_name"
    
    # Update registry with sync date (if needed, implement this later)
    return 0
}

# Function to sync all registered projects
sync_all_projects() {
    print_status "Starting framework sync for all registered projects..."
    
    local project_paths=($(get_project_paths))
    local success_count=0
    local total_count=${#project_paths[@]}
    
    if [[ $total_count -eq 0 ]]; then
        print_warning "No projects found in registry"
        return 1
    fi
    
    for path in "${project_paths[@]}"; do
        # Extract project name from path (simple approach)
        local project_name=$(basename "$(dirname "$path")")
        
        if sync_project "$path" "$project_name"; then
            success_count=$((success_count + 1))
        fi
        echo ""  # Add spacing between projects
    done
    
    print_success "Sync completed: $success_count/$total_count projects updated"
}

# Function to sync specific project by name or path
sync_specific_project() {
    local search_term="$1"
    local project_paths=($(get_project_paths))
    local found=false
    
    for path in "${project_paths[@]}"; do
        if [[ "$path" == *"$search_term"* ]] || [[ $(basename "$(dirname "$path")") == "$search_term" ]]; then
            local project_name=$(basename "$(dirname "$path")")
            sync_project "$path" "$project_name"
            found=true
            break
        fi
    done
    
    if [[ "$found" != true ]]; then
        print_error "Project not found: $search_term"
        print_status "Available projects:"
        for path in "${project_paths[@]}"; do
            echo "  - $(basename "$(dirname "$path")") ($path)"
        done
        return 1
    fi
}

# Function to add new project to registry
add_project() {
    local project_name="$1"
    local project_path="$2"
    
    if [[ -z "$project_name" ]] || [[ -z "$project_path" ]]; then
        print_error "Usage: add_project <project_name> <project_path>"
        return 1
    fi
    
    if [[ ! -d "$project_path" ]]; then
        print_error "Project path does not exist: $project_path"
        return 1
    fi
    
    # Add to registry (simple append - could be more sophisticated)
    local today=$(date +"%Y-%m-%d")
    echo "| $project_name | \`$project_path\` | ACTIVE | $CURRENT_VERSION | $today | |" >> "$REGISTRY_FILE"
    
    print_success "Added $project_name to registry"
    
    # Sync framework to new project
    sync_project "$project_path" "$project_name"
}

# Function to show help
show_help() {
    echo "Chat History Framework Sync Tool"
    echo ""
    echo "Usage:"
    echo "  $0 all                           - Sync all registered projects"
    echo "  $0 project <name_or_path>        - Sync specific project"
    echo "  $0 add <name> <path>             - Add new project and sync"
    echo "  $0 list                          - List registered projects"
    echo "  $0 --help                        - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 all"
    echo "  $0 project my-web-app"
    echo "  $0 add \"My New Project\" \"/path/to/project/docs/chat_history\""
    echo ""
}

# Function to list projects
list_projects() {
    print_status "Registered projects:"
    local project_paths=($(get_project_paths))
    
    if [[ ${#project_paths[@]} -eq 0 ]]; then
        print_warning "No projects registered"
        return 1
    fi
    
    for path in "${project_paths[@]}"; do
        local project_name=$(basename "$(dirname "$path")")
        echo "  - $project_name ($path)"
    done
}

# Main script logic
case "${1:-}" in
    "all")
        sync_all_projects
        ;;
    "project")
        if [[ -z "${2:-}" ]]; then
            print_error "Project name or path required"
            show_help
            exit 1
        fi
        sync_specific_project "$2"
        ;;
    "add")
        if [[ -z "${2:-}" ]] || [[ -z "${3:-}" ]]; then
            print_error "Project name and path required"
            show_help
            exit 1
        fi
        add_project "$2" "$3"
        ;;
    "list")
        list_projects
        ;;
    "--help"|"help"|"")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac