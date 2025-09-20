# MEV Shield Hook Makefile
# Provides convenient commands for development, testing, and deployment

.PHONY: help install build test test-unit test-fuzz test-integration coverage clean deploy deploy-testnet deploy-mainnet deploy-anvil format lint gas-report

# Default target
help:
	@echo "MEV Shield Hook - Available Commands:"
	@echo ""
	@echo "Development:"
	@echo "  install          Install all dependencies"
	@echo "  build           Build all contracts"
	@echo "  clean           Clean build artifacts"
	@echo ""
	@echo "Testing:"
	@echo "  test            Run all tests"
	@echo "  test-unit       Run unit tests only"
	@echo "  test-fuzz       Run fuzz tests only"
	@echo "  test-integration Run integration tests only"
	@echo "  coverage        Generate test coverage report"
	@echo ""
	@echo "Code Quality:"
	@echo "  format          Format Solidity code"
	@echo "  lint            Run linter"
	@echo "  gas-report      Generate gas usage report"
	@echo ""
	@echo "Deployment:"
	@echo "  deploy-anvil    Deploy to local Anvil network"
	@echo "  deploy-testnet  Deploy to Fhenix testnet"
	@echo "  deploy-mainnet  Deploy to Fhenix mainnet"
	@echo ""
	@echo "Utilities:"
	@echo "  verify          Verify contracts on Etherscan"
	@echo "  fork-test       Run tests on forked network"

# =============================================================================
# Development Commands
# =============================================================================

install:
	@echo "Installing dependencies..."
	forge install
	@echo "Dependencies installed successfully!"

build:
	@echo "Building contracts..."
	forge build --via-ir
	@echo "Build completed!"

clean:
	@echo "Cleaning build artifacts..."
	forge clean
	rm -rf out/ cache/ broadcast/ forge-snapshots/
	@echo "Clean completed!"

# =============================================================================
# Testing Commands
# =============================================================================

test:
	@echo "Running all tests..."
	forge test --via-ir
	@echo "All tests completed!"

test-unit:
	@echo "Running unit tests..."
	forge test --match-path "test/unit/*" --via-ir
	@echo "Unit tests completed!"

test-fuzz:
	@echo "Running fuzz tests..."
	forge test --match-path "test/fuzz/*" --via-ir
	@echo "Fuzz tests completed!"

test-integration:
	@echo "Running integration tests..."
	forge test --match-path "test/integration/*" --via-ir
	@echo "Integration tests completed!"

coverage:
	@echo "Generating coverage report..."
	forge coverage --ir-minimum
	@echo "Coverage report generated!"

coverage-lcov:
	@echo "Generating LCOV coverage report..."
	forge coverage --ir-minimum --report lcov
	@echo "LCOV coverage report generated!"

# =============================================================================
# Code Quality Commands
# =============================================================================

format:
	@echo "Formatting Solidity code..."
	forge fmt
	@echo "Code formatting completed!"

lint:
	@echo "Running linter..."
	forge lint
	@echo "Linting completed!"

gas-report:
	@echo "Generating gas report..."
	forge test --gas-report --via-ir
	@echo "Gas report generated!"

# =============================================================================
# Deployment Commands
# =============================================================================

deploy-anvil:
	@echo "Deploying to Anvil network..."
	forge script script/Deploy.s.sol --rpc-url $(ANVIL_RPC_URL) --broadcast --via-ir
	@echo "Deployment to Anvil completed!"

deploy-testnet:
	@echo "Deploying to Fhenix testnet..."
	forge script script/Deploy.s.sol --rpc-url $(FHENIX_TESTNET_RPC_URL) --broadcast --via-ir --verify
	@echo "Deployment to testnet completed!"

deploy-mainnet:
	@echo "Deploying to Fhenix mainnet..."
	@echo "WARNING: This will deploy to mainnet!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ]
	forge script script/Deploy.s.sol --rpc-url $(FHENIX_MAINNET_RPC_URL) --broadcast --via-ir --verify
	@echo "Deployment to mainnet completed!"

# =============================================================================
# Utility Commands
# =============================================================================

verify:
	@echo "Verifying contracts..."
	forge verify-contract --chain-id $(FHENIX_TESTNET_CHAIN_ID) --watch
	@echo "Contract verification completed!"

fork-test:
	@echo "Running tests on forked network..."
	forge test --fork-url $(TEST_FORK_URL) --via-ir
	@echo "Fork tests completed!"

# =============================================================================
# Advanced Testing Commands
# =============================================================================

test-mev-detection:
	@echo "Running MEV detection tests..."
	forge test --match-test "testMEVDetection" --via-ir
	@echo "MEV detection tests completed!"

test-protection:
	@echo "Running protection mechanism tests..."
	forge test --match-test "testProtection" --via-ir
	@echo "Protection tests completed!"

test-fhe:
	@echo "Running FHE operation tests..."
	forge test --match-test "testFHE" --via-ir
	@echo "FHE tests completed!"

# =============================================================================
# Development Utilities
# =============================================================================

snapshot:
	@echo "Creating test snapshot..."
	forge snapshot --via-ir
	@echo "Snapshot created!"

size:
	@echo "Checking contract sizes..."
	forge build --sizes --via-ir
	@echo "Contract size analysis completed!"

# =============================================================================
# Environment Setup
# =============================================================================

setup-env:
	@echo "Setting up environment..."
	cp .env.example .env
	@echo "Environment file created! Please edit .env with your values."

# =============================================================================
# Documentation
# =============================================================================

docs:
	@echo "Generating documentation..."
	@echo "Documentation generation not yet implemented"
	@echo "Please refer to README.md for current documentation"

# =============================================================================
# CI/CD Helpers
# =============================================================================

ci-test:
	@echo "Running CI test suite..."
	forge test --via-ir --gas-report --summary
	@echo "CI tests completed!"

ci-coverage:
	@echo "Running CI coverage..."
	forge coverage --ir-minimum --report lcov
	@echo "CI coverage completed!"

# =============================================================================
# Quick Development Workflow
# =============================================================================

dev-setup: install setup-env build test
	@echo "Development environment setup complete!"

quick-test: build test-unit
	@echo "Quick test completed!"

full-test: build test coverage gas-report
	@echo "Full test suite completed!"

# =============================================================================
# Emergency Commands
# =============================================================================

emergency-pause:
	@echo "Emergency pause functionality not yet implemented"
	@echo "Please use the contract's pause function directly"

# =============================================================================
# Help for specific commands
# =============================================================================

help-test:
	@echo "Testing Commands:"
	@echo "  test            - Run all tests"
	@echo "  test-unit       - Run only unit tests"
	@echo "  test-fuzz       - Run only fuzz tests"
	@echo "  test-integration - Run only integration tests"
	@echo "  coverage        - Generate coverage report"
	@echo "  coverage-lcov   - Generate LCOV coverage report"

help-deploy:
	@echo "Deployment Commands:"
	@echo "  deploy-anvil    - Deploy to local Anvil network"
	@echo "  deploy-testnet  - Deploy to Fhenix testnet"
	@echo "  deploy-mainnet  - Deploy to Fhenix mainnet (requires confirmation)"
	@echo "  verify          - Verify deployed contracts"

help-dev:
	@echo "Development Commands:"
	@echo "  install         - Install all dependencies"
	@echo "  build           - Build all contracts"
	@echo "  clean           - Clean build artifacts"
	@echo "  format          - Format Solidity code"
	@echo "  lint            - Run linter"
	@echo "  gas-report      - Generate gas usage report"
