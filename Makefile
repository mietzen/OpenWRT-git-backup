.PHONY: help clean

help:
	@echo "OpenWRT Git Backup - LuCI Plugin"
	@echo ""
	@echo "This is an OpenWRT package that should be built using the OpenWRT SDK."
	@echo ""
	@echo "Building:"
	@echo "  Packages are automatically built via GitHub Actions on PR and main branch"
	@echo "  Download pre-built packages from GitHub Releases"
	@echo ""
	@echo "Manual build:"
	@echo "  1. Download OpenWRT SDK for your architecture"
	@echo "  2. Copy luci-app-git-backup/ to SDK's package/ directory"
	@echo "  3. Run: make package/luci-app-git-backup/compile"
	@echo ""
	@echo "Installation:"
	@echo "  opkg install luci-app-git-backup_*.ipk"
	@echo ""

clean:
	@echo "Nothing to clean (builds happen in OpenWRT SDK)"

# Default target
.DEFAULT_GOAL := help
