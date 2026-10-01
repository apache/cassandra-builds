# Makefile for Cassandra Environment Manager

# Build variables
BINARY_NAME=cassandra-env-manager
BUILD_DIR=build
CMD_DIR=./cmd

# Go build flags
LDFLAGS=-ldflags="-s -w"
GCFLAGS=-gcflags="all=-trimpath=$(PWD)"
ASMFLAGS=-asmflags="all=-trimpath=$(PWD)"

# Default target
all: build

# Build for current platform
build:
	@echo "Building $(BINARY_NAME) for current platform..."
	go build $(LDFLAGS) $(GCFLAGS) $(ASMFLAGS) -o $(BINARY_NAME) $(CMD_DIR)

# Build for all platforms
build-all: build-linux build-darwin build-windows

# Build for Linux
build-linux:
	@echo "Building $(BINARY_NAME) for Linux..."
	@mkdir -p $(BUILD_DIR)
	GOOS=linux GOARCH=amd64 go build $(LDFLAGS) $(GCFLAGS) $(ASMFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 $(CMD_DIR)
	GOOS=linux GOARCH=arm64 go build $(LDFLAGS) $(GCFLAGS) $(ASMFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-arm64 $(CMD_DIR)

# Build for macOS
build-darwin:
	@echo "Building $(BINARY_NAME) for macOS..."
	@mkdir -p $(BUILD_DIR)
	GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) $(GCFLAGS) $(ASMFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-amd64 $(CMD_DIR)
	GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) $(GCFLAGS) $(ASMFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-arm64 $(CMD_DIR)

# Build for Windows
build-windows:
	@echo "Building $(BINARY_NAME) for Windows..."
	@mkdir -p $(BUILD_DIR)
	GOOS=windows GOARCH=amd64 go build $(LDFLAGS) $(GCFLAGS) $(ASMFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-windows-amd64.exe $(CMD_DIR)

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -f $(BINARY_NAME)

# Run tests
test:
	@echo "Running tests..."
	go test ./...

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	go test -cover ./...

# Format code
fmt:
	@echo "Formatting code..."
	go fmt ./...

# Lint code (requires golangci-lint)
lint:
	@echo "Linting code..."
	golangci-lint run

# Install dependencies
deps:
	@echo "Installing dependencies..."
	go mod tidy
	go mod download

# Run the application (for development)
run:
	@echo "Running $(BINARY_NAME)..."
	go run $(CMD_DIR) $(ARGS)

# Install the binary to GOPATH/bin
install:
	@echo "Installing $(BINARY_NAME)..."
	go install $(LDFLAGS) $(GCFLAGS) $(ASMFLAGS) $(CMD_DIR)

# Create release packages
release: build-all
	@echo "Creating release packages..."
	@mkdir -p $(BUILD_DIR)/releases
	cd $(BUILD_DIR) && tar -czf releases/$(BINARY_NAME)-linux-amd64.tar.gz $(BINARY_NAME)-linux-amd64
	cd $(BUILD_DIR) && tar -czf releases/$(BINARY_NAME)-linux-arm64.tar.gz $(BINARY_NAME)-linux-arm64
	cd $(BUILD_DIR) && tar -czf releases/$(BINARY_NAME)-darwin-amd64.tar.gz $(BINARY_NAME)-darwin-amd64
	cd $(BUILD_DIR) && tar -czf releases/$(BINARY_NAME)-darwin-arm64.tar.gz $(BINARY_NAME)-darwin-arm64
	cd $(BUILD_DIR) && zip releases/$(BINARY_NAME)-windows-amd64.zip $(BINARY_NAME)-windows-amd64.exe

# Check for required tools
check-tools:
	@echo "Checking for required tools..."
	@command -v go >/dev/null 2>&1 || { echo "Go is required but not installed"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed"; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || { echo "Docker Compose is required but not installed"; exit 1; }
	@echo "All required tools are available"

# Development setup
dev-setup: check-tools deps
	@echo "Development environment setup complete"

# Help target
help:
	@echo "Cassandra Environment Manager - Makefile Help"
	@echo ""
	@echo "Available targets:"
	@echo "  build          Build for current platform"
	@echo "  build-all      Build for all platforms (Linux, macOS, Windows)"
	@echo "  build-linux    Build for Linux (amd64, arm64)"
	@echo "  build-darwin   Build for macOS (amd64, arm64)"
	@echo "  build-windows  Build for Windows (amd64)"
	@echo "  clean          Clean build artifacts"
	@echo "  test           Run tests"
	@echo "  test-coverage  Run tests with coverage"
	@echo "  fmt            Format code"
	@echo "  lint           Lint code (requires golangci-lint)"
	@echo "  deps           Install dependencies"
	@echo "  run            Run the application (use ARGS for arguments)"
	@echo "  install        Install binary to GOPATH/bin"
	@echo "  release        Create release packages"
	@echo "  check-tools    Check for required tools"
	@echo "  dev-setup      Setup development environment"
	@echo "  help           Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make run ARGS='--help'"
	@echo "  make run ARGS='--status'"
	@echo "  make build-all"

.PHONY: all build build-all build-linux build-darwin build-windows clean test test-coverage fmt lint deps run install release check-tools dev-setup help