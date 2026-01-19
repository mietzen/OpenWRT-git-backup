.PHONY: help build clean test docker-build

help:
	@echo "LuCI Git Backup - Build Commands"
	@echo ""
	@echo "Usage:"
	@echo "  make docker-build    Build IPK package using Docker (Mac/Windows)"
	@echo "  make build          Build IPK package (Linux only)"
	@echo "  make clean          Clean build artifacts"
	@echo "  make test           Run tests on package structure"
	@echo ""

docker-build:
	@./docker-build.sh

build:
	@./build-package.sh

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf build/
	@rm -rf packages/
	@echo "✓ Clean complete"

test:
	@echo "Running package structure tests..."
	@./test-package-structure.sh

# Default target
.DEFAULT_GOAL := help
