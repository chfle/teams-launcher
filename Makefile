.PHONY: all lint test install uninstall

SHELL := /bin/bash

all: lint test

lint:
	@echo "==> Linting shell scripts..."
	shellcheck bin/teams-launcher install.sh uninstall.sh tests/run.sh

test:
	@echo "==> Running tests..."
	bash tests/run.sh

install:
	bash install.sh

uninstall:
	bash uninstall.sh
