#!/bin/bash

# Git Flow Hotfix Helper Script
# Usage: ./scripts/git-flow-hotfix.sh [start|finish] [version]

set -e

HOTFIX_PREFIX="hotfix/"
DEVELOP_BRANCH="develop"
MAIN_BRANCH="main"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_usage() {
    echo -e "${BLUE}Git Flow Hotfix Helper${NC}"
    echo ""
    echo "Usage: $0 [command] [version-or-name]"
    echo ""
    echo "Commands:"
    echo "  start [version]   - Start a new hotfix branch"
    echo "  finish [version]  - Finish and merge a hotfix branch"
    echo "  list              - List all hotfix branches"
    echo ""
    echo "Examples:"
    echo "  $0 start 1.0.1"
    echo "  $0 start fix-auth-bug"
    echo "  $0 finish 1.0.1"
    echo "  $0 list"
}

start_hotfix() {
    local NAME=$1

    if [ -z "$NAME" ]; then
        echo -e "${RED}Error: Hotfix name/version required${NC}"
        print_usage
        exit 1
    fi

    local BRANCH_NAME="${HOTFIX_PREFIX}${NAME}"

    echo -e "${BLUE}Starting new hotfix: ${NAME}${NC}"
    echo ""

    # Switch to main
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ]; then
        echo -e "${YELLOW}Switching to ${MAIN_BRANCH} branch...${NC}"
        git checkout $MAIN_BRANCH
    fi

    # Pull latest changes
    echo -e "${YELLOW}Pulling latest changes from origin/${MAIN_BRANCH}...${NC}"
    git pull origin $MAIN_BRANCH

    # Create hotfix branch
    echo -e "${YELLOW}Creating hotfix branch: ${BRANCH_NAME}${NC}"
    git checkout -b $BRANCH_NAME

    # Push to remote
    echo -e "${YELLOW}Pushing branch to remote...${NC}"
    git push -u origin $BRANCH_NAME

    echo ""
    echo -e "${GREEN}✓ Hotfix branch created successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Fix the bug"
    echo "  2. Test thoroughly"
    echo "  3. Commit: git add . && git commit -m 'fix: description'"
    echo "  4. Update version: npm version patch --no-git-tag-version"
    echo "  5. Commit version: git add . && git commit -m 'chore: bump version'"
    echo "  6. Push: git push"
    echo "  7. Create Pull Request: ${BRANCH_NAME} → ${MAIN_BRANCH}"
    echo "  8. After PR merged, run: $0 finish $NAME"
}

finish_hotfix() {
    local NAME=$1

    if [ -z "$NAME" ]; then
        echo -e "${RED}Error: Hotfix name/version required${NC}"
        print_usage
        exit 1
    fi

    local BRANCH_NAME="${HOTFIX_PREFIX}${NAME}"

    echo -e "${BLUE}Finishing hotfix: ${NAME}${NC}"
    echo ""

    # Get version from package.json on main
    git checkout $MAIN_BRANCH
    git pull origin $MAIN_BRANCH

    VERSION=$(node -p "require('./package.json').version")
    TAG_NAME="v${VERSION}"

    # Create and push tag
    echo -e "${YELLOW}Creating tag ${TAG_NAME}...${NC}"
    git tag -a $TAG_NAME -m "Hotfix version ${VERSION}"
    git push origin $TAG_NAME

    # Merge back to develop
    echo -e "${YELLOW}Merging back to ${DEVELOP_BRANCH}...${NC}"
    git checkout $DEVELOP_BRANCH
    git pull origin $DEVELOP_BRANCH
    git merge $MAIN_BRANCH
    git push origin $DEVELOP_BRANCH

    # Delete hotfix branch
    echo -e "${YELLOW}Deleting hotfix branch...${NC}"
    git branch -d $BRANCH_NAME 2>/dev/null || true
    git push origin --delete $BRANCH_NAME 2>/dev/null || true

    echo ""
    echo -e "${GREEN}✓ Hotfix finished successfully!${NC}"
    echo -e "${BLUE}Tag ${TAG_NAME} created and pushed${NC}"
    echo -e "${BLUE}You are now on ${DEVELOP_BRANCH} branch${NC}"
}

list_hotfixes() {
    echo -e "${BLUE}Hotfix Branches:${NC}"
    echo ""

    # List local hotfix branches
    echo -e "${YELLOW}Local:${NC}"
    git branch | grep "^[* ]*${HOTFIX_PREFIX}" | sed "s/^[* ]*/  - /" || echo "  No local hotfix branches"

    echo ""

    # List remote hotfix branches
    echo -e "${YELLOW}Remote:${NC}"
    git branch -r | grep "origin/${HOTFIX_PREFIX}" | sed "s/^  origin\//  - /" || echo "  No remote hotfix branches"
}

# Main script
case "$1" in
    start)
        start_hotfix "$2"
        ;;
    finish)
        finish_hotfix "$2"
        ;;
    list)
        list_hotfixes
        ;;
    *)
        print_usage
        exit 1
        ;;
esac
