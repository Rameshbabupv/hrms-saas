#!/bin/bash

# Git Flow Feature Helper Script
# Usage: ./scripts/git-flow-feature.sh [start|finish] [feature-name]

set -e

FEATURE_PREFIX="feature/"
DEVELOP_BRANCH="develop"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_usage() {
    echo -e "${BLUE}Git Flow Feature Helper${NC}"
    echo ""
    echo "Usage: $0 [command] [feature-name]"
    echo ""
    echo "Commands:"
    echo "  start [name]   - Start a new feature branch"
    echo "  finish [name]  - Finish and merge a feature branch"
    echo "  list           - List all feature branches"
    echo ""
    echo "Examples:"
    echo "  $0 start employee-management"
    echo "  $0 finish employee-management"
    echo "  $0 list"
}

start_feature() {
    local FEATURE_NAME=$1

    if [ -z "$FEATURE_NAME" ]; then
        echo -e "${RED}Error: Feature name required${NC}"
        print_usage
        exit 1
    fi

    local BRANCH_NAME="${FEATURE_PREFIX}${FEATURE_NAME}"

    echo -e "${BLUE}Starting new feature: ${FEATURE_NAME}${NC}"
    echo ""

    # Check if already on develop
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "$DEVELOP_BRANCH" ]; then
        echo -e "${YELLOW}Switching to ${DEVELOP_BRANCH} branch...${NC}"
        git checkout $DEVELOP_BRANCH
    fi

    # Pull latest changes
    echo -e "${YELLOW}Pulling latest changes from origin/${DEVELOP_BRANCH}...${NC}"
    git pull origin $DEVELOP_BRANCH

    # Create and switch to feature branch
    echo -e "${YELLOW}Creating feature branch: ${BRANCH_NAME}${NC}"
    git checkout -b $BRANCH_NAME

    # Push to remote
    echo -e "${YELLOW}Pushing branch to remote...${NC}"
    git push -u origin $BRANCH_NAME

    echo ""
    echo -e "${GREEN}✓ Feature branch created successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Make your changes"
    echo "  2. Commit: git add . && git commit -m 'feat: your message'"
    echo "  3. Push: git push"
    echo "  4. Create Pull Request on GitHub"
    echo "  5. Run: $0 finish $FEATURE_NAME (after PR is merged)"
}

finish_feature() {
    local FEATURE_NAME=$1

    if [ -z "$FEATURE_NAME" ]; then
        echo -e "${RED}Error: Feature name required${NC}"
        print_usage
        exit 1
    fi

    local BRANCH_NAME="${FEATURE_PREFIX}${FEATURE_NAME}"

    echo -e "${BLUE}Finishing feature: ${FEATURE_NAME}${NC}"
    echo ""

    # Check if branch exists
    if ! git show-ref --verify --quiet refs/heads/$BRANCH_NAME; then
        echo -e "${RED}Error: Branch ${BRANCH_NAME} does not exist${NC}"
        exit 1
    fi

    # Switch to feature branch
    echo -e "${YELLOW}Switching to ${BRANCH_NAME}...${NC}"
    git checkout $BRANCH_NAME

    # Pull latest changes
    echo -e "${YELLOW}Pulling latest changes...${NC}"
    git pull origin $BRANCH_NAME

    # Switch to develop
    echo -e "${YELLOW}Switching to ${DEVELOP_BRANCH}...${NC}"
    git checkout $DEVELOP_BRANCH

    # Pull latest develop
    echo -e "${YELLOW}Pulling latest ${DEVELOP_BRANCH}...${NC}"
    git pull origin $DEVELOP_BRANCH

    # Delete local branch
    echo -e "${YELLOW}Deleting local branch ${BRANCH_NAME}...${NC}"
    git branch -d $BRANCH_NAME

    # Delete remote branch (if exists)
    if git ls-remote --exit-code --heads origin $BRANCH_NAME > /dev/null 2>&1; then
        echo -e "${YELLOW}Deleting remote branch ${BRANCH_NAME}...${NC}"
        git push origin --delete $BRANCH_NAME
    fi

    echo ""
    echo -e "${GREEN}✓ Feature finished successfully!${NC}"
    echo -e "${BLUE}You are now on ${DEVELOP_BRANCH} branch${NC}"
}

list_features() {
    echo -e "${BLUE}Feature Branches:${NC}"
    echo ""

    # List local feature branches
    echo -e "${YELLOW}Local:${NC}"
    git branch | grep "^[* ]*${FEATURE_PREFIX}" | sed "s/^[* ]*/  - /" || echo "  No local feature branches"

    echo ""

    # List remote feature branches
    echo -e "${YELLOW}Remote:${NC}"
    git branch -r | grep "origin/${FEATURE_PREFIX}" | sed "s/^  origin\//  - /" || echo "  No remote feature branches"
}

# Main script
case "$1" in
    start)
        start_feature "$2"
        ;;
    finish)
        finish_feature "$2"
        ;;
    list)
        list_features
        ;;
    *)
        print_usage
        exit 1
        ;;
esac
