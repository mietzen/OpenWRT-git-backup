#!/bin/bash
# Build git-backup IPK package using Docker (for Mac/Windows)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Building luci-app-git-backup in Docker"
echo "=========================================="
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not running"
    echo "Please start Docker Desktop and try again"
    exit 1
fi

# Build Docker image
echo "1. Building Docker image..."
docker build -t luci-git-backup-builder "$SCRIPT_DIR"
echo "   ✓ Docker image built"
echo ""

# Run build in container
echo "2. Running build in container..."
docker run --rm \
    -v "$SCRIPT_DIR:/build" \
    -w /build \
    luci-git-backup-builder \
    /bin/bash -c "./build-package.sh"

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="
echo ""
echo "Package location:"
ls -lh "$SCRIPT_DIR/packages/"*.ipk
echo ""
echo "Next steps:"
echo "1. Copy to OpenWrt:"
echo "   scp packages/luci-app-git-backup_*.ipk root@<openwrt-ip>:/tmp/"
echo ""
echo "2. Install on OpenWrt:"
echo "   ssh root@<openwrt-ip>"
echo "   opkg install /tmp/luci-app-git-backup_*.ipk"
echo ""
