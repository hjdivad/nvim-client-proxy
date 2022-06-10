
# This Makefile creates a project-private prefix ".deps/usr" with all
# dependencies required for building/testing.

# local.mk is ignored by git, use it for local build settings.
-include local.mk

# Use TEST_TAG=foo to pass --tags=foo to busted.
_TEST_TAG := $(if $(TEST_TAG),--tags=$(TEST_TAG),)

PLATFORM := $(shell uname -s)

# Dependencies prefix
DEPS_DIR ?= $(shell pwd)/.deps
DEPS_PREFIX ?= $(DEPS_DIR)/usr
DEPS_BIN ?= $(DEPS_PREFIX)/bin

# Lua-related configuration
LUA_URL ?= http://www.lua.org/ftp/lua-5.1.5.tar.gz
LUAROCKS_URL ?= https://github.com/keplerproject/luarocks/archive/v2.2.0.tar.gz

ifeq ($(PLATFORM), Darwin)
LUA_TARGET ?= macosx
else
LUA_TARGET ?= linux
endif

LUA ?= $(DEPS_BIN)/lua
LUAROCKS ?= $(DEPS_BIN)/luarocks
BUSTED ?= $(DEPS_BIN)/busted
MPACK ?= $(DEPS_PREFIX)/lib/luarocks/rocks/mpack
NVIM_CLIENT ?= $(DEPS_PREFIX)/lib/luarocks/rocks/nvim_client

INSTALL_MPACK ?= $(LUAROCKS) install mpack
INSTALL_NVIMN_CLIENT ?= $(LUAROCKS) install nvim-client

# Misc
# Options used by the 'valgrind' target, which runs the tests under valgrind
VALGRIND_OPTS ?= --log-file=valgrind.log --leak-check=yes --track-origins=yes
# Command that will download a file and pipe it's contents to stdout
FETCH ?= curl -L -o -
# Command that will gunzip/untar a file from stdin to the current directory,
# stripping one directory component
UNTGZ ?= tar xfz - --strip-components=1

all: deps

deps: | $(MPACK) $(NVIM_CLIENT) $(BUSTED)

test: all
	NVIM_LOG_FILE=nvimlog $(BUSTED) -v $(_TEST_TAG) \
		'--lpath=./src/?.lua;./test/?.lua' -o gtest src

valgrind: all
	eval $$($(LUAROCKS) path); \
	valgrind $(VALGRIND_OPTS) $(LUA) \
		$(DEPS_PREFIX)/lib/luarocks/rocks/busted/2.0.rc11-0/bin/busted \
		'--lpath=./src/?.lua;./test/?.lua' test
	cat valgrind.log

clean:
	@echo 'I am always clean'

distclean: clean
	rm -rf $(DEPS_DIR)

$(BUSTED): | $(LUAROCKS)
	$(LUAROCKS) install busted
	$(LUAROCKS) install inspect  # helpful for debugging

$(MPACK): $(LUAROCKS)
	$(INSTALL_MPACK)

$(NVIM_CLIENT): $(LUAROCKS)
	$(INSTALL_NVIM_CLIENT)

$(LUAROCKS): $(LUA)
	dir="$(DEPS_DIR)/src/luarocks"; \
	mkdir -p $$dir && cd $$dir && \
	$(FETCH) $(LUAROCKS_URL) | $(UNTGZ) && \
	./configure --prefix=$(DEPS_PREFIX) --force-config \
		--with-lua=$(DEPS_PREFIX) && make bootstrap

$(LUA):
	dir="$(DEPS_DIR)/src/lua"; \
	mkdir -p $$dir && cd $$dir && \
	$(FETCH) $(LUA_URL) | $(UNTGZ) && \
	sed -i -e '/^CFLAGS/s/-O2/-g/' src/Makefile && \
	make $(LUA_TARGET) install INSTALL_TOP=$(DEPS_PREFIX)

.PHONY: all deps test valgrind clean distclean
