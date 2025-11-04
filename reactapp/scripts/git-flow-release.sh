#!/bin/bash

# Git Flow Release Helper Script
# Usage: ./scripts/git-flow-release.sh [start|finish] [version]

set -e

RELEASE_PREFIX="release/"
DEVELOP_BRANCH="develop"
MAIN_BRANCH="main"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_usage() {
    echo -e "${BLUE}Git Flow Release Helper${NC}"
    echo ""
    echo "Usage: $0 [command] [version]"
    echo ""
    echo "Commands:"
    echo "  start [version]   - Start a new release branch"
    echo "  finish [version]  - Finish and merge a release branch"
    echo "  list              - List all release branches"
    echo ""
    echo "Examples:"
    echo "  $0 start 1.2.0"
    echo "  $0 finish 1.2.0"
    echo "  $0 list"
}

validate_version() {
    local VERSION=$1

    if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid version format. Use X.Y.Z (e.g., 1.2.0)${NC}"
        exit 1
    fi
}

start_release() {
    local VERSION=$1

    if [ -z "$VERSION" ]; then
        echo -e "${RED}Error: Version required${NC}"
        print_usage
        exit 1
    fi

    validate_version "$VERSION"

    local BRANCH_NAME="${RELEASE_PREFIX}v${VERSION}"

    echo -e "${BLUE}Starting new release: v${VERSION}${NC}"
    echo ""

    # Switch to develop
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "$DEVELOP_BRANCH" ]; then
        echo -e "${YELLOW}Switching to ${DEVELOP_BRANCH} branch...${NC}"
        git checkout $DEVELOP_BRANCH
    fi

    # Pull latest changes
    echo -e "${YELLOW}Pulling latest changes from origin/${DEVELOP_BRANCH}...${NC}"
    git pull origin $DEVELOP_BRANCH

    # Create release branch
    echo -e "${YELLOW}Creating release branch: ${BRANCH_NAME}${NC}"
    git checkout -b $BRANCH_NAME

    # Update version in package.json
    echo -e "${YELLOW}Updating version in package.json...${NC}"
    npm version $VERSION --no-git-tag-version

    # Commit version bump
    git add package.json package-lock.json
    git commit -m "chore: bump version to ${VERSION}"

    # Push to remote
    echo -e "${YELLOW}Pushing branch to remote...${NC}"
    git push -u origin $BRANCH_NAME

    echo ""
    echo -e "${GREEN}✓ Release branch created successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Fix any last-minute bugs"
    echo "  2. Update documentation"
    echo "  3. Run final tests"
    echo "  4. Create Pull Request: ${BRANCH_NAME} → ${MAIN_BRANCH}"
    echo "  5. After PR merged, run: $0 finish $VERSION"
}

finish_release() {
    local VERSION=$1

    if [ -z "$VERSION" ]; then
        echo -e "${RED}Error: Version required${NC}"
        print_usage
        exit 1
    fi

    validate_version "$VERSION"

    local BRANCH_NAME="${RELEASE_PREFIX}v${VERSION}"
    local TAG_NAME="v${VERSION}"

    echo -e "${BLUE}Finishing release: v${VERSION}${NC}"
    echo ""

    # Pull latest main
    echo -e "${YELLOW}Pulling latest ${MAIN_BRANCH}...${NC}"
    git checkout $MAIN_BRANCH
    git pull origin $MAIN_BRANCH

    # Create and push tag
    echo -e "${YELLOW}Creating tag ${TAG_NAME}...${NC}"
    git tag -a $TAG_NAME -m "Release version ${VERSION}"
    git push origin $TAG_NAME

    # Merge back to develop
    echo -e "${YELLOW}Merging back to ${DEVELOP_BRANCH}...${NC}"
    git checkout $DEVELOP_BRANCH
    git pull origin $DEVELOP_BRANCH
    git merge $MAIN_BRANCH
    git push origin $DEVELOP_BRANCH

    # Delete release branch
    echo -e "${YELLOW}Deleting release branch...${NC}"
    git branch -d $BRANCH_NAME 2>/dev/null || true
    git push origin --delete $BRANCH_NAME 2>/dev/null || true

    echo ""
    echo -e "${GREEN}✓ Release finished successfully!${NC}"
    echo -e "${BLUE}Tag ${TAG_NAME} created and pushed${NC}"
    echo -e "${BLUE}You are now on ${DEVELOP_BRANCH} branch${NC}"
}

list_releases() {
    echo -e "${BLUE}Release Branches:${NC}"
    echo ""

    # List local release branches
    echo -e "${YELLOW}Local:${NC}"
    git branch | grep "^[* ]*${RELEASE_PREFIX}" | sed "s/^[* ]*/  - /" || echo "  No local release branches"

    echo ""

    # List remote release branches
    echo -e "${YELLOW}Remote:${NC}"
    git branch -r | grep "origin/${RELEASE_PREFIX}" | sed "s/^  origin\//  - /" || echo "  No remote release branches"

    echo ""

    # List tags
    echo -e "${YELLOW}Tags (last 10):${NC}"
    git tag --sort=-creatordate | head -10 | sed "s/^/  - /" || echo "  No tags"
}

# Main script
case "$1" in
    start)
        start_release "$2"
        ;;
    finish)
        finish_release "$2"
        ;;
    list)
        list_releases
        ;;
    *)
        print_usage
        exit 1
        ;;
esac
