PKG_ID  := org.plasma.appgrid
VERSION := $(shell python3 -c 'import json; print(json.load(open("$(PKG_ID)/metadata.json"))["KPlugin"]["Version"])')
DIST    := dist
PLASMOID := $(DIST)/$(PKG_ID)-$(VERSION).plasmoid

.PHONY: all package install upgrade uninstall clean

all: package

package:
	mkdir -p $(DIST)
	rm -f $(PLASMOID)
	cd $(PKG_ID) && zip -r -9 ../$(PLASMOID) metadata.json contents

install:
	kpackagetool6 --type Plasma/Applet --install $(PKG_ID)

upgrade:
	kpackagetool6 --type Plasma/Applet --upgrade $(PKG_ID)

uninstall:
	kpackagetool6 --type Plasma/Applet --remove $(PKG_ID)

clean:
	rm -rf $(DIST)
