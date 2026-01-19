#!/bin/bash
# Build the luci-app-git-backup package

set -e

echo "=========================================="
echo "Building luci-app-git-backup Package"
echo "=========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$SCRIPT_DIR/luci-app-git-backup"
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT_DIR="$SCRIPT_DIR/packages"

# Check if package directory exists
if [ ! -d "$PKG_DIR" ]; then
    echo "Error: Package directory not found: $PKG_DIR"
    exit 1
fi

# Clean previous build
echo "1. Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"
echo "   ✓ Clean complete"
echo ""

# Create package structure
echo "2. Creating package structure..."
INSTALL_DIR="$BUILD_DIR/luci-app-git-backup"
mkdir -p "$INSTALL_DIR"

# Copy all files from root/ to package
if [ -d "$PKG_DIR/root" ]; then
    echo "   Copying root files..."
    cp -r "$PKG_DIR/root/"* "$INSTALL_DIR/"
fi

# Copy LuCI files
if [ -d "$PKG_DIR/luasrc" ]; then
    echo "   Copying LuCI files..."
    mkdir -p "$INSTALL_DIR/usr/lib/lua/luci"
    cp -r "$PKG_DIR/luasrc/"* "$INSTALL_DIR/usr/lib/lua/luci/"
fi

echo "   ✓ Package structure created"
echo ""

# Create CONTROL directory
echo "3. Creating control files..."
mkdir -p "$INSTALL_DIR/CONTROL"

# Extract package info from Makefile
VERSION=$(grep "PKG_VERSION:=" "$PKG_DIR/Makefile" | cut -d'=' -f2)
RELEASE=$(grep "PKG_RELEASE:=" "$PKG_DIR/Makefile" | cut -d'=' -f2)
DEPENDS="luci-compat, git, git-http, ca-bundle, wget, luci-base"

cat > "$INSTALL_DIR/CONTROL/control" << EOF
Package: luci-app-git-backup
Version: $VERSION-$RELEASE
Depends: $DEPENDS
Section: luci
Architecture: all
Maintainer: OpenWRT Git Backup Contributors
Description: LuCI Support for Git Backup
 Web interface for automatic Git-based configuration backups.
 Provides event-driven backup of /etc/config to a remote git repository
 with support for SSH and HTTPS authentication.
EOF

# Create postinst script
cat > "$INSTALL_DIR/CONTROL/postinst" << 'EOF'
#!/bin/sh
# Post-installation script

# Enable and start the service
if [ -f /etc/init.d/git-backup-hook ]; then
    /etc/init.d/git-backup-hook enable
    /etc/init.d/git-backup-hook start
fi

# Clear LuCI cache
rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache/* 2>/dev/null || true

# Restart uhttpd to reload LuCI
/etc/init.d/uhttpd restart 2>/dev/null || true

echo "Git Backup LuCI app installed successfully"
echo "Access it at: System > Git Backup"

exit 0
EOF

# Create prerm script
cat > "$INSTALL_DIR/CONTROL/prerm" << 'EOF'
#!/bin/sh
# Pre-removal script

# Stop the service
if [ -f /etc/init.d/git-backup-hook ]; then
    /etc/init.d/git-backup-hook stop
    /etc/init.d/git-backup-hook disable
fi

exit 0
EOF

chmod +x "$INSTALL_DIR/CONTROL/postinst"
chmod +x "$INSTALL_DIR/CONTROL/prerm"

echo "   ✓ Control files created"
echo ""

# Set correct permissions
echo "4. Setting file permissions..."
find "$INSTALL_DIR" -type f -name "*.sh" -exec chmod +x {} \;
chmod +x "$INSTALL_DIR/usr/bin/git-backup" 2>/dev/null || true
chmod +x "$INSTALL_DIR/etc/init.d/git-backup-hook" 2>/dev/null || true
echo "   ✓ Permissions set"
echo ""

# Build the ipk
echo "5. Building IPK package..."
cd "$BUILD_DIR"

# Create package using tar and gzip (standard ipk format)
PKG_FILE="luci-app-git-backup_${VERSION}-${RELEASE}_all.ipk"

# Create data archive
cd luci-app-git-backup
tar czf ../data.tar.gz --exclude=CONTROL .
cd ..

# Create control archive
cd luci-app-git-backup/CONTROL
tar czf ../../control.tar.gz .
cd ../..

# Create debian-binary
echo "2.0" > debian-binary

# Combine into ipk
ar r "$PKG_FILE" debian-binary control.tar.gz data.tar.gz

# Move to output directory
mv "$PKG_FILE" "$OUTPUT_DIR/"

echo "   ✓ Package built"
echo ""

echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo ""
echo "Package: $OUTPUT_DIR/$PKG_FILE"
echo ""
echo "To install on OpenWrt:"
echo "1. Copy package to your OpenWrt device:"
echo "   scp $OUTPUT_DIR/$PKG_FILE root@openwrt:/tmp/"
echo ""
echo "2. SSH to OpenWrt and install:"
echo "   ssh root@openwrt"
echo "   opkg install /tmp/$PKG_FILE"
echo ""
