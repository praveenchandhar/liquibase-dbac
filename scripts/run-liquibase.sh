#!/bin/bash

# Docker-based Liquibase Runner Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# MongoDB connection base
MONGO_BASE="mongodb+srv://praveenchandharts:kixIUsDWGd3n6w5S@praveen-mongodb-github.lhhwdqa.mongodb.net"

# Valid databases
VALID_DATABASES="sample_mflix liquibase_test liquibase_test_new"

# Functions
print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

usage() {
    echo "Usage: $0 <command> <database> [version] [environment]"
    echo ""
    echo "Commands:"
    echo "  status  - Check changeset status"
    echo "  update  - Apply changesets"
    echo ""
    echo "Databases:"
    echo "  sample_mflix, liquibase_test, liquibase_test_new"
    echo ""
    echo "Examples:"
    echo "  $0 status sample_mflix                    # Latest changeset status"
    echo "  $0 update sample_mflix 24092025          # Specific version"
    echo "  $0 update sample_mflix latest            # Latest changeset"
    exit 1
}

# Validate arguments
if [ $# -lt 2 ]; then
    usage
fi

COMMAND="$1"
DATABASE="$2"
VERSION_OR_FILE="${3:-latest}"
ENVIRONMENT="${4:-weekly_release}"

# Validate command
if [[ "$COMMAND" != "status" && "$COMMAND" != "update" ]]; then
    print_error "Invalid command: $COMMAND"
    usage
fi

# Validate database
if [[ ! " $VALID_DATABASES " =~ " $DATABASE " ]]; then
    print_error "Invalid database: $DATABASE"
    echo "Valid databases: $VALID_DATABASES"
    exit 1
fi

print_info "Starting Docker-based Liquibase execution..."
print_info "Command: $COMMAND"
print_info "Database: $DATABASE"
print_info "Version/File: $VERSION_OR_FILE"
print_info "Environment: $ENVIRONMENT"

# Find changeset file
if [[ "$VERSION_OR_FILE" == *.yaml ]]; then
    print_info "Using direct file path: $VERSION_OR_FILE"
    CHANGESET_FILE="$VERSION_OR_FILE"
else
    CHANGESET_DIR="$PROJECT_ROOT/db/mongodb/$ENVIRONMENT"
    
    if [ ! -d "$CHANGESET_DIR" ]; then
        print_error "Changeset directory not found: $CHANGESET_DIR"
        exit 1
    fi

    # Find YAML files
    if [ "$VERSION_OR_FILE" = "latest" ]; then
        CHANGESET_FILE=$(find "$CHANGESET_DIR" -name "*.yaml" -type f | sort | tail -1)
    else
        CHANGESET_FILE=$(find "$CHANGESET_DIR" -path "*$VERSION_OR_FILE*" -name "*.yaml" -type f | head -1)
    fi

    if [ -z "$CHANGESET_FILE" ]; then
        print_error "No changeset file found for version: $VERSION_OR_FILE"
        print_info "Available changesets:"
        find "$CHANGESET_DIR" -name "*.yaml" -type f | sort
        exit 1
    fi
    
    # Convert to relative path from PROJECT_ROOT
    if command -v realpath >/dev/null 2>&1; then
        CHANGESET_FILE=$(realpath --relative-to="$PROJECT_ROOT" "$CHANGESET_FILE")
    else
        # Fallback for macOS/systems without realpath
        CHANGESET_FILE=$(python3 -c "import os; print(os.path.relpath('$CHANGESET_FILE', '$PROJECT_ROOT'))")
    fi
fi

print_status "Using changeset: $CHANGESET_FILE"

# Move to project root directory for relative paths
cd "$PROJECT_ROOT"

# MongoDB connection string
MONGO_URL="${MONGO_BASE}/${DATABASE}?retryWrites=true&w=majority&tls=true"
print_info "MongoDB URL: ****/${DATABASE}?..."
print_info "Context: $DATABASE"
print_info "Working directory: $(pwd)"
print_info "Changeset path: $CHANGESET_FILE"

# Show changeset preview
print_info "Changeset preview:"
echo "===================="
head -20 "$CHANGESET_FILE" || echo "Could not read file"
echo "===================="

# Execute Liquibase using Docker
print_info "Executing Liquibase $COMMAND using Docker (no Java module issues)..."

# Create a temporary Docker Compose file for Liquibase
cat > liquibase-temp.yml << EOF
version: '3.8'
services:
  liquibase:
    image: liquibase/liquibase:4.20.0
    volumes:
      - .:/liquibase/changelog
    working_dir: /liquibase/changelog
    environment:
      - LIQUIBASE_COMMAND_URL=$MONGO_URL
      - LIQUIBASE_COMMAND_USERNAME=
      - LIQUIBASE_COMMAND_PASSWORD=
    command: >
      --changeLogFile=$CHANGESET_FILE
      --contexts=$DATABASE
      --logLevel=INFO
      $COMMAND
EOF

# Run Liquibase with Docker Compose
docker-compose -f liquibase-temp.yml run --rm liquibase

exit_code=$?

# Cleanup
rm -f liquibase-temp.yml

print_info "Docker Liquibase execution completed with exit code: $exit_code"

if [ $exit_code -eq 0 ]; then
    print_status "Liquibase $COMMAND completed successfully!"
else
    print_error "Liquibase $COMMAND failed with exit code: $exit_code"
fi

exit $exit_code
