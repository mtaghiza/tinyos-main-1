include $(TOPDIR)/rules.mk 

PKG_NAME:=tinyos-telos-monitor
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/tinyos-telos-monitor
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=TinyOS Serial Listener
  MAINTAINER:=Razvan Musaloiu-E. <razvanm@cs.jhu.edu>
endef

define Package/tinyos-telos-monitor/description
  JHU telos-monitor for NSLU2.
endef 

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) $(TARGET_CONFIGURE_OPTS)
endef

define Package/tinyos-telos-monitor/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/etc/hotplug.d/usb
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/telos-monitor $(1)/usr/bin/telos-monitor
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/proxy $(1)/usr/bin/proxy
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/11-telos-monitor $(1)/etc/hotplug.d/usb
endef

$(eval $(call BuildPackage,tinyos-telos-monitor))
