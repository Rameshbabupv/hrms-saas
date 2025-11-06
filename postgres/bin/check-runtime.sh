#!/bin/bash
# ==============================================================================
# Container Runtime Check Script
# Checks if Podman or Docker is available and properly configured
# ==============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Container Runtime Check"
echo "=========================================="
echo ""

# Check for Podman
echo "🔍 Checking for Podman..."
if command -v podman &> /dev/null; then
    PODMAN_VERSION=$(podman --version)
    echo -e "   ${GREEN}✅ Podman found: ${PODMAN_VERSION}${NC}"

    # Check Podman machine (macOS only)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo ""
        echo "🖥️  Checking Podman machine..."
        if podman machine list &> /dev/null; then
            MACHINE_STATUS=$(podman machine list --format "{{.Name}}: {{.Running}}" 2>/dev/null)
            if [ -n "$MACHINE_STATUS" ]; then
                echo "   Machine Status:"
                echo "$MACHINE_STATUS" | while IFS= read -r line; do
                    if [[ $line == *"true"* ]]; then
                        echo -e "   ${GREEN}✅ $line${NC}"
                    else
                        echo -e "   ${RED}❌ $line${NC}"
                    fi
                done

                # Check if any machine is running
                if podman machine list --format "{{.Running}}" 2>/dev/null | grep -q "true"; then
                    echo -e "   ${GREEN}✅ Podman machine is running${NC}"
                    PODMAN_READY=true
                else
                    echo -e "   ${RED}❌ No Podman machine is running${NC}"
                    echo ""
                    echo "To start Podman machine:"
                    echo -e "   ${BLUE}podman machine start${NC}"
                    PODMAN_READY=false
                fi
            else
                echo -e "   ${RED}❌ No Podman machine configured${NC}"
                echo ""
                echo "To initialize and start Podman:"
                echo -e "   ${BLUE}podman machine init${NC}"
                echo -e "   ${BLUE}podman machine start${NC}"
                PODMAN_READY=false
            fi
        fi
    else
        # Linux doesn't need machine
        PODMAN_READY=true
    fi

    # Test Podman connectivity
    if [ "$PODMAN_READY" = true ]; then
        echo ""
        echo "🔗 Testing Podman connectivity..."
        if podman ps &> /dev/null; then
            echo -e "   ${GREEN}✅ Podman is accessible${NC}"
            PODMAN_WORKS=true
        else
            echo -e "   ${RED}❌ Cannot connect to Podman${NC}"
            PODMAN_WORKS=false
        fi
    else
        PODMAN_WORKS=false
    fi
else
    echo -e "   ${RED}❌ Podman not found${NC}"
    PODMAN_WORKS=false
fi

echo ""
echo "=========================================="

# Check for Docker
echo ""
echo "🔍 Checking for Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "   ${GREEN}✅ Docker found: ${DOCKER_VERSION}${NC}"

    # Test Docker connectivity
    echo ""
    echo "🔗 Testing Docker connectivity..."
    if docker ps &> /dev/null; then
        echo -e "   ${GREEN}✅ Docker is accessible${NC}"
        DOCKER_WORKS=true
    else
        echo -e "   ${RED}❌ Cannot connect to Docker daemon${NC}"
        echo ""
        echo "Possible causes:"
        echo "   1. Docker Desktop not running"
        echo "   2. Docker daemon not started"
        echo "   3. Permission issues"
        echo ""
        echo "To start Docker Desktop (macOS):"
        echo -e "   ${BLUE}open -a Docker${NC}"
        DOCKER_WORKS=false
    fi
else
    echo -e "   ${RED}❌ Docker not found${NC}"
    DOCKER_WORKS=false
fi

echo ""
echo "=========================================="

# Summary
echo ""
echo "📋 Summary:"
echo ""

if [ "$PODMAN_WORKS" = true ]; then
    echo -e "${GREEN}✅ Podman is ready to use${NC}"
    RUNTIME_AVAILABLE=true
elif [ "$DOCKER_WORKS" = true ]; then
    echo -e "${GREEN}✅ Docker is ready to use${NC}"
    RUNTIME_AVAILABLE=true
else
    echo -e "${RED}❌ No container runtime is available${NC}"
    RUNTIME_AVAILABLE=false
fi

echo ""

if [ "$RUNTIME_AVAILABLE" = true ]; then
    echo "You can now run the database scripts:"
    echo -e "   ${BLUE}./db-start.sh${NC}      - Start database"
    echo -e "   ${BLUE}./db-status.sh${NC}     - Check status"
    echo -e "   ${BLUE}./db-stop.sh${NC}       - Stop database"
    echo -e "   ${BLUE}./db-restart.sh${NC}    - Restart database"
else
    echo "Installation instructions:"
    echo ""
    echo "For Podman (recommended):"
    echo -e "   ${BLUE}brew install podman${NC}"
    echo -e "   ${BLUE}podman machine init${NC}"
    echo -e "   ${BLUE}podman machine start${NC}"
    echo ""
    echo "For Docker:"
    echo -e "   ${BLUE}brew install --cask docker${NC}"
    echo "   Or download from: https://www.docker.com/products/docker-desktop"
fi

echo ""
echo "=========================================="
echo ""

# Exit with appropriate code
if [ "$RUNTIME_AVAILABLE" = true ]; then
    exit 0
else
    exit 1
fi
