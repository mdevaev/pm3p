-include config.mk

BOARD ?= zero2w
STAGES ?= __init__ os pikvm-repo watchdog rootdelay no-bluetooth no-audit ro pm3p ssh-keygen __cleanup__

HOSTNAME ?= pm3p
LOCALE ?= en_US
TIMEZONE ?= Europe/Nicosia
REPO_URL ?= http://de3.mirror.archlinuxarm.org
BUILD_OPTS ?=

ROOT_PASSWD ?= root

SUDO ?= sudo

CARD ?= /dev/mmcblk0


# =====
SHELL = /usr/bin/env bash
_BUILDER_DIR = ./.pi-builder

define optbool
$(filter $(shell echo $(1) | tr A-Z a-z),yes on 1)
endef


# =====
all:
	@ echo "Available commands:"
	@ echo "    make                # Print this help"
	@ echo "    make os             # Build OS with your default config"
	@ echo "    make shell          # Run Arch-ARM shell"
	@ echo "    make install        # Install rootfs to partitions on $(CARD)"
	@ echo "    make scan           # Find all RPi devices in the local network"
	@ echo "    make clean          # Remove the generated rootfs"
	@ echo "    make clean-all      # Remove the generated rootfs and pi-builder toolchain"


shell: $(_BUILDER_DIR)
	$(MAKE) -C $(_BUILDER_DIR) shell


os: $(_BUILDER_DIR)
	rm -rf $(_BUILDER_DIR)/stages/pm3p
	cp -a pm3p $(_BUILDER_DIR)/stages
	$(MAKE) -C $(_BUILDER_DIR) os \
		NC=$(NC) \
		BUILD_OPTS=' $(BUILD_OPTS) \
			--build-arg ROOT_PASSWD=$(ROOT_PASSWD) \
		' \
		PROJECT=pm3p-os \
		BOARD=$(BOARD) \
		STAGES='$(STAGES)' \
		HOSTNAME=$(HOSTNAME) \
		LOCALE=$(LOCALE) \
		TIMEZONE=$(TIMEZONE) \
		REPO_URL=$(REPO_URL)


$(_BUILDER_DIR):
	mkdir -p `dirname $(_BUILDER_DIR)`
	git clone --depth=1 https://github.com/pikvm/pi-builder $(_BUILDER_DIR)


update: $(_BUILDER_DIR)
	cd $(_BUILDER_DIR) && git pull --rebase
	git pull --rebase


install: $(_BUILDER_DIR)
	$(MAKE) -C $(_BUILDER_DIR) install CARD=$(CARD)


scan: $(_BUILDER_DIR)
	$(MAKE) -C $(_BUILDER_DIR) scan


clean: $(_BUILDER_DIR)
	$(MAKE) -C $(_BUILDER_DIR) clean


clean-all:
	- $(MAKE) -C $(_BUILDER_DIR) clean-all
	rm -rf $(_BUILDER_DIR)
	- rmdir `dirname $(_BUILDER_DIR)`
