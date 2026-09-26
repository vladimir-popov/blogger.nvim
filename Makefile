NVIM_TEST_DIR ?= .nvim-test
NVIM_TEST_REPO ?= https://github.com/lewis6991/nvim-test
NVIM_TEST_REF ?= main
NVIM_TEST_BIN := $(NVIM_TEST_DIR)/bin/nvim-test
LUA_PATH := $(CURDIR)/lua/?.lua

.PHONY: setup test test-file

$(NVIM_TEST_BIN):
	git clone --depth 1 --branch "$(NVIM_TEST_REF)" "$(NVIM_TEST_REPO)" "$(NVIM_TEST_DIR)"

setup: $(NVIM_TEST_BIN)
	$(NVIM_TEST_BIN) --init

test: setup
	$(NVIM_TEST_BIN) spec --lpath "$(LUA_PATH)"

test-file: setup
	@test -n "$(FILE)" || (echo "Usage: make test-file FILE=spec/markdown_spec.lua" && exit 1)
	$(NVIM_TEST_BIN) "$(FILE)" --lpath "$(LUA_PATH)"
