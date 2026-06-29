# Makefile for st (Smalltalk Universal Installer)
# Standard targets: lint, format, test, check, clean
# See: https://www.gnu.org/software/make/manual/

SHELL := /usr/bin/env bash
.SHELLFLAGS := -Eeuo pipefail -c

# Project paths
BIN_DIR    := bin
LIBEXEC_DIR := libexec
TESTS_DIR  := tests
SCRIPTS    := $(BIN_DIR)/st \
              $(LIBEXEC_DIR)/smalltalk-common.sh \
              $(LIBEXEC_DIR)/smalltalk-pharo.sh \
              $(LIBEXEC_DIR)/smalltalk-squeak.sh \
              $(LIBEXEC_DIR)/smalltalk-cuis.sh \
              $(LIBEXEC_DIR)/smalltalk-gt.sh \
              $(LIBEXEC_DIR)/smalltalk-gnu.sh \
              $(LIBEXEC_DIR)/smalltalk-lst.sh \
              $(LIBEXEC_DIR)/smalltalk-ls4.sh \
              install.sh \
              tests/runSmalltalkTests \
              tests/runStCollectEnv \
              $(LIBEXEC_DIR)/helpers.sh \
              $(LIBEXEC_DIR)/deploy.sh

# Colors for output
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
NC     := \033[0m

.PHONY: all lint shellcheck shfmt format test check clean help \
        security install uninstall release version

# Default target
all: lint test

# ============================================================================
# Help
# ============================================================================

help: ## Show this help message
	@printf "${BLUE}st - Smalltalk Universal Installer${NC}\n\n"
	@printf "${GREEN}Available targets:${NC}\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  ${YELLOW}%-15s${NC} %s\n", $$1, $$2}' | \
		sort

# ============================================================================
# Static Analysis & Formatting
# ============================================================================

lint: shellcheck shfmt ## Run all linters (ShellCheck + shfmt check)

shellcheck: ## Run ShellCheck static analysis
	@printf "${BLUE}==> Running ShellCheck...${NC}\n"
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck --severity=warning --external-sources $(SCRIPTS) && \
		printf "${GREEN}==> ShellCheck passed${NC}\n"; \
	else \
		printf "${YELLOW}==> shellcheck not found. Install: brew install shellcheck${NC}\n"; \
	fi

shfmt: ## Check formatting with shfmt (dry-run)
	@printf "${BLUE}==> Checking formatting with shfmt...${NC}\n"
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -d -i 4 -ci -bn -sr -kp $(SCRIPTS) && \
		printf "${GREEN}==> Formatting check passed${NC}\n"; \
	else \
		printf "${YELLOW}==> shfmt not found. Install: brew install shfmt${NC}\n"; \
	fi

format: ## Auto-format all shell scripts with shfmt
	@printf "${BLUE}==> Formatting shell scripts...${NC}\n"
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -w -i 4 -ci -bn -sr -kp $(SCRIPTS) && \
		printf "${GREEN}==> Formatted${NC}\n"; \
	else \
		printf "${YELLOW}==> shfmt not found. Install: brew install shfmt${NC}\n"; \
	fi

# ============================================================================
# Testing
# ============================================================================

test: ## Run all Bats tests
	@printf "${BLUE}==> Running tests...${NC}\n"
	@chmod +x $(BIN_DIR)/st
	@./tests/runSmalltalkTests -v

test-quick: ## Run quick smoke tests only
	@printf "${BLUE}==> Running quick smoke tests...${NC}\n"
	@chmod +x $(BIN_DIR)/st
	@bats $(TESTS_DIR)/test-smalltalk.bats --filter "runs without arguments|shows usage|help|version"

check: lint test ## Run linting AND tests (full CI check)

# ============================================================================
# Security
# ============================================================================

security: ## Run security checks (dangerous patterns, gitleaks)
	@printf "${BLUE}==> Running security scan...${NC}\n"
	@DANGEROUS=0; \
	for f in $(SCRIPTS); do \
		if grep -nE 'eval\s+.*\$$' "$$f" 2>/dev/null; then \
			printf "${RED}WARNING: eval with variable in $$f${NC}\n"; \
			DANGEROUS=1; \
		fi; \
	done; \
	for f in $(SCRIPTS); do \
		if grep -nE 'rm\s+-rf\s+[^-]' "$$f" 2>/dev/null | grep -v '/tmp' | grep -v 'CACHE'; then \
			printf "${RED}WARNING: rm -rf without -- in $$f${NC}\n"; \
			DANGEROUS=1; \
		fi; \
	done; \
	if command -v gitleaks >/dev/null 2>&1; then \
		gitleaks detect --no-git || true; \
	fi; \
	if [[ $$DANGEROUS -eq 1 ]]; then \
		printf "${RED}==> Security issues found!${NC}\n"; \
		exit 1; \
	fi; \
	printf "${GREEN}==> Security scan passed${NC}\n"

# ============================================================================
# Installation
# ============================================================================

install: ## Install st to ~/.st/st/bin
	@printf "${BLUE}==> Installing st...${NC}\n"
	@bash install.sh

uninstall: ## Remove st installation
	@printf "${BLUE}==> Uninstalling st...${NC}\n"
	@rm -rf "${HOME}/.st/st"
	@printf "${GREEN}==> Uninstalled. Remove from PATH manually if needed.${NC}\n"

# ============================================================================
# Release
# ============================================================================

version: ## Show current version
	@cat VERSION

release: ## Create a new release (requires release-it)
	@printf "${BLUE}==> Creating release...${NC}\n"
	@./libexec/deploy.sh

# ============================================================================
# Clean
# ============================================================================

clean: ## Remove build artifacts, temp files, and caches
	@printf "${BLUE}==> Cleaning...${NC}\n"
	@rm -rf st_troubleshoot_*.txt
	@rm -rf /tmp/st-*.tmp /tmp/smalltalk*.tmp 2>/dev/null || true
	@find . -name '*.bak' -delete 2>/dev/null || true
	@find . -name '*.orig' -delete 2>/dev/null || true
	@printf "${GREEN}==> Cleaned${NC}\n"

clean-cache: ## Remove Smalltalk cache directory
	@printf "${BLUE}==> Cleaning Smalltalk cache...${NC}\n"
	@rm -rf "${HOME}/.smalltalk-cache"
	@printf "${GREEN}==> Cache cleaned${NC}\n"