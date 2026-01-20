# Copyright 2026 OpenWRT Git Backup
# Licensed under MIT

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-git-backup
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=OpenWRT Git Backup Contributors

LUCI_TITLE:=LuCI Support for Git Backup

# Dependencies are automatically installed by opkg when this package is installed
# The + prefix indicates hard dependencies that must be present
# Note: LuCI CBI requires Lua runtime - using lua or luci-lua-runtime depending on OpenWRT version
LUCI_DEPENDS:=+luci-compat +git +git-http +ca-bundle +wget +luci-base +inotifywait +lua

LUCI_DESCRIPTION:=Web interface for automatic Git-based configuration backups

include $(TOPDIR)/feeds/luci/luci.mk

define Package/luci-app-git-backup/postinst
#!/bin/sh
# Enable and start the UCI hook service
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/git-backup-hook enable
	/etc/init.d/git-backup-hook start
	exit 0
}
endef

# call BuildPackage - OpenWrt buildroot signature
